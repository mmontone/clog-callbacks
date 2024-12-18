# clog-callbacks

Callbacks implementation for CLOG

Some javascript components need to execute some arbitrary javascript on the client, following some particular JS api. This CLOG extension allows that and at the same time bind some function server side that can access arbitrary data sent from the client side Javascript component.

So I came up with this implementation of callbacks. Callback functions are defined via defcallback and then invoked from javascript via call-callback (call-callback actually generates the javascript needed  to call the callback function).

For example, this is how I'm using it for a graph component I'm trying to integrate:

Define a callback function. `args` is an arbitrary json object sent from the client:

```lisp
(clog-callbacks:defcallback graph-double-click (args)
  (let* ((node-id (car (access:access args :nodes)))
	 (obj (nth node-id *objects*)))
    (show obj)))
```

Generate js code following a js component api that calls the server-side callback and sends arbitrary js arguments to it:

```lisp
(defun graph-set-on-double-click (graph stream)
  "Handle double click events for GRAPH."
  (format stream "~a.on('doubleClick', function (params) {
params.event = '[original event]';
~a
})"
	  (js-handle graph)
	  (clog-callbacks:call-callback 'graph-double-click "JSON.stringify(params)")))
``` 
