var net = require('net');
var util = require('util');
var express = require('express');
var path = require('path');
var app = express();
var server = require('http').createServer(app);
var io  = require('socket.io').listen(server,{log:false});
var fs  = require('fs')
var log = function() {
	console.log.apply(console, arguments);
}
var config = {
	http : {port:8080},	
}
app.use(express.bodyParser({
	keepExtensions : true,
	uploadDir : __dirname + '/public/videos'
}));
app.use(express.static(__dirname + '/public'));
app.set('views', __dirname + '/views');
app.set('view engine', 'jade');
app.set("view options", { layout: false });
app.get('/', function(req, res){
	res.render('home.jade');
});

var sockets = [];

app.post('/video', function(req,res){	
	res.json(200,{});
	sockets.broadcast(path.basename(req.files.video.path));	
});

Array.prototype.remove = function() {
    var what, a = arguments, L = a.length, ax;
    while (L && this.length) {
        what = a[--L];
        while ((ax = this.indexOf(what)) !== -1) {
            this.splice(ax, 1);
        }
    }
    return this;
};

log('http server listening at ' + config.http.port);
server.listen(config.http.port);
sockets.broadcast = function(file) {
	console.log('broadcasting file %s to %d sockets', file, this.length);
	this.forEach(function(socket){
		socket.emit('newVideo', file);		
	});
}.bind(sockets);

io.sockets.on('connection', function (socket) {	
	sockets.push(socket);
	log('connected %d', sockets.length);
	socket.on('disconnect', function() {
		sockets.remove(socket);
		log('disconnected %d', sockets.length);
	});	
});