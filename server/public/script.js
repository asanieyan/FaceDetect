var Queue = function() {
	this.baseURL 	= '/videos';
	this.currentIdx = 0;
	this.videos 	= [];
}
Queue.prototype = {
	play : function() {
		this.playNextVideo();
	},
	setCurrentVideoIndex : function(idx) {
		console.log('setting current video to ' + idx);
		if ( this.currentVideo ) {
			console.log('removing the current video');
			this.currentVideo.remove();
		}
		this.currentVideo = this.videos[idx];
		this.currentVideo.bind('ended', function(){	
			console.log('finished playing video ' + this.currentVideo.attr('src'));
			this.playNextVideo();
		}.bind(this));
		this.currentIdx   = idx;	
		$(document.body).append(this.currentVideo);
		return this.currentVideo[0];
	},		
	addVideo : function(name) 
	{
		var video = $('<video>');
		video.attr('src',this.baseURL + "/" + name );		
		//video.load();
		console.log('queuing the video ' + name);
		this.videos.push(video);
		if ( !this.currentVideo ) {
			console.log('queue empty playing the first video ');
			this.setCurrentVideoIndex(0).play();
		}
		else if ( this.currentVideo[0].ended ) {
			console.log('current video %s ended, playing the next video', this.currentVideo.attr('src'));		
			this.playNextVideo();
		} 
	},
	playNextVideo : function() {
		if ( this.currentIdx + 1 < this.videos.length ) {
			this.setCurrentVideoIndex(this.currentIdx + 1).play();
		} else {

		}
	}
}

var queue = new Queue();
window.onload = function() {
	queue.play();
    var socket = io.connect('http://localhost:8080');
    socket.on('newVideo', function (video) {    	
		queue.addVideo(video);
    });
}