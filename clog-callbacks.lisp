(mgl-pax:define-package :clog-callbacks
    (:documentation "The Common List Omnificent GUI - Callbacks")
  (:use #:cl #:mgl-pax)
  (:export
   :register-callback
   :find-callback
   :defcallback
   :call-callback
   :callback
   :handle-callback
   :*callbacks*))

(in-package :clog-callbacks)

(defvar *callbacks* (make-hash-table :test 'equalp)
  "The table of callbacks.")

(defun register-callback (name handler)
  "Register HANDLER as a callback under NAME."
  (setf (gethash name *callbacks*) handler))

(defun find-callback (name &key (error-p t))
  "Find callback named with NAME."
  (or (gethash name *callbacks*)
      (and error-p
           (error "Callback not defined: ~s" name))))

(defmacro defcallback (name args &body body)
  "Define a callback function."
  `(progn
     (defun ,name ,args ,@body)
     (register-callback ,(princ-to-string name) #',name)))

(defun call-callback (name-or-lambda args)
  "Returns the javascript code for calling a registered callback function.
NAME-OR-LAMBDA can be either:
- A symbol. Should name a callback defined via DEFCALLBACK.
- A function. Probably a lambda. Gets registered as callback and called.
ARGS is a javascript expression (string) that returns a JSON with the arguments for the callback."
  (cond
    ((symbolp name-or-lambda)
     (format nil "ws.send('C:~a:' + ~a)" name-or-lambda args))
    ((functionp name-or-lambda)
     ;; assign a name and register the callback first
     (let ((callback-name (gensym "CALLBACK-")))
       (register-callback (princ-to-string callback-name) name-or-lambda)
       (format nil "ws.send('C:~a:' + ~a)" callback-name args)))
    (t (error "Invalid callback: ~s" name-or-lambda))))

(defun callback (name-or-lambda)
  "Create a callback. Returns a lambda expression that when applied to arguments return the javascript code that makes the call to the server callback.
NAME-OR-LAMBDA can be either:
- A symbol. Should name a callback defined via DEFCALLBACK.
- A function. Probably a lambda. Gets registered as callback and called."
  (cond
    ((symbolp name-or-lambda)
     (lambda (args)
       (format nil "ws.send('C:~a:' + ~a)" name-or-lambda args)))
    ((functionp name-or-lambda)
     ;; assign a name and register the callback first
     (let ((callback-name (gensym "CALLBACK-")))
       (register-callback (princ-to-string callback-name) name-or-lambda)
       (lambda (args)
         (format nil "ws.send('C:~a:' + ~a)" callback-name args))))
    (t (error "Invalid callback: ~s" name-or-lambda))))

(defun handle-callback (name args)
  (let ((callback (find-callback name)))
    (funcall callback args)))

(defun clog-message-handler (ml connection-id)
  (when (equal (first ml) "C")
    ;; a callback
    ;; message format: 'C:name:args'
    ;; args are in json format
    (let ((ml (ppcre:split ":" (second ml) :limit 2)))
      (destructuring-bind (_ cb-name cb-args) ml
	(declare (ignore _))
	(when *verbose-output*
          (format t "Connection ~A    Callback = ~A    Args = ~A~%"
                  connection-id cb-name cb-args))
	(bordeaux-threads:make-thread
	 (lambda ()
           (if clog-connection:*break-on-error*
               (handle-callback cb-name (json:decode-json-from-string cb-args))
               (handler-case
                   (handle-callback cb-name (json:decode-json-from-string cb-args))
		 (t (c)
                   (format t "Condition caught in handle-message for callback - ~A.~&" cb-name)
                   (values 0 c)))))
	 :name (format nil "CLOG callack handler ~A" cb-name))))
    t))

(pushnew 'clog-message-handler clog-connection::*message-handlers*)
