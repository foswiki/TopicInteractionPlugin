/*
 * foswiki legacy file upload plugin 1.0
 *
 * Copyright (c) 2018 Michael Daum http://michaeldaumconsulting.com
 *
 * Licensed GPL http://www.gnu.org/licenses/gpl.html
 *
 */
"use strict";

// plupload statics
var plupload = {
  STOPPED: 1,
  STARTED: 2,
  QUEUED: 1,
  UPLOADING: 2,
  FAILED: 4,
  DONE: 5
};

(function($) {


  // legacy uploader, wrapper around new implementation 
  function LegacyUploader(elem, opts) {
    var self = this,
        wrapper = $(elem).wrap("<div />").parent().addClass("jqLegacyUploader jqUploadButton");

    self.wrapper = wrapper;
    self.elem = $(elem);
    self.fileInput = $("<input />").attr("type", "file").appendTo(wrapper);
    self.opts = $.extend({}, self.elem.data(), opts);
    self.init();
  };

  LegacyUploader.prototype.init = function() {
    var self = this;
    
    self.state = plupload.STOPPED;
    self.files = [];
    self.browseButton = $(self.opts.browseButton) || self.wrapper;
    self.browseButton.uploadButton(self.opts).addClass("jqUploadButtonInited");

    // we only simulate those events that we actually need in jquery.natedit
    $("body").bind("fileuploadadd", function(e, data) {
      self.files = data.files;
      self.state = plupload.QUEUED;
      self.trigger("QueueChange");
    }).bind("fileuploadstart", function(e, data) {
      self.state = plupload.STARTED;
      self.files[0].percent = 0;
      self.trigger("StateChanged");
    }).bind("fileuploadstop", function(e, data) {
      self.files = [];
      self.state = plupload.STOPPED;
    }).bind("fileuploaddone", function() {
      self.state = plupload.STOPPED;
      self.files[0].percent = 100;
      self.trigger("StateChanged");
    });
  };

  LegacyUploader.prototype.bind = function(signal, fn) {
    var self = this;

    self.elem.bind(signal, fn);
  };

  LegacyUploader.prototype.trigger = function(signal) {
    var self = this;

    return self.elem.trigger(signal);
  };

  // add to jquery
  $.fn.uploader = function(opts) {
    console.warn("this uploader api is deprecated, please switch to new fileupload api");
    return this.each(function () { 
      if (!$.data(this, "uploader")) { 
        $.data(this, "uploader", new LegacyUploader(this, opts)); 
      } 
    });
  };

})(jQuery);

