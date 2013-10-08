FaceDetect
==========

It's a utility sample app that uses AVFoundation to transmit almost live video feed from an iPhone to a node.js server. 

The recording is triggered when face features are detected, then video feed are buffered in 10 seconds segments and sent to the  node.js server.

On the browser site, we use socket.io to establish a web socket connection with the server as soon as videos are ready to be rendered, they are sent to the browser. 

Get started
===========

The server code is located at ROOT/server

to run the server 

`node server.js`

The server listens to port localhost:8080
