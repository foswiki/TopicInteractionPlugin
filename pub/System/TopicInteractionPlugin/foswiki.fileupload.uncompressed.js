/*
 * foswiki file upload plugin 1.0
 *
 * Copyright (c) 2016 Michael Daum http://michaeldaumconsulting.com
 *
 * Dual licensed under the MIT and GPL licenses:
 *   http://www.opensource.org/licenses/mit-license.php
 *   http://www.gnu.org/licenses/gpl.html
 *
 */

"use strict";
(function($) {

  // The actual plugin constructor 
  function FileUploadButton(elem, opts) { 
    var self = this;

    self.elem = $(elem); 
    self.opts = $.extend({
      topic: foswiki.getPreference("WEB")+"."+foswiki.getPreference("TOPIC")
    }, self.elem.data(), opts); 
    self.init(); 
  } 

  FileUploadButton.prototype.init = function () { 
    var self = this, dropZone;

    self.fileElem = self.elem.find("input[type=file]");
    self.bar = self.elem.find(".jqFileUploadProgressBar");
    self.progressInfo = self.elem.find(".jqFileUploadProgressInfo");
    self.uploadedFiles = [];

    dropZone = self.elem.find(".jqFileUploadDropZone");
    dropZone.remove();
    $(".jqFileUploadDropZone").remove();
    dropZone.appendTo("body");

    self.fileElem.fileupload({
      url: foswiki.getScriptUrl("rest", "JQFileUploadPlugin", "upload", {
        topic: self.opts.topic
      }),
      dataType: 'json',
      pasteZone: $(document),
      sequentialUploads: true,
      singleFileUploads: true,
      progressall: function (e, data) {
        var progress = parseInt(data.loaded / data.total * 100, 10);
        self.bar.css("width", progress+"%");
        self.progressInfo.html(self.renderExtendedProgress(data));
      },
      add: function(e, data) {
        data.formData = self.opts;
        data.submit();
      },
      start: function() {
        self.bar.width(0);
        self.uploadedFiles = [];
        $.blockUI({
          blockMsgClass: "jqFileUploadMsg",
          message: self.bar
        });
      },
      stop: function() {
        $.pnotify({
          text: $.i18n("Uploaded %num% file(s)", {num: self.uploadedFiles.length}),
          type: "success",
          delay: 1000 
        });
        $(".foswikiAttachments").trigger("refresh", [self.uploadedFiles]);
        $.unblockUI();
      },
      dragover: function() {
        if (self.dragoverTimer) {
          window.clearTimeout(self.dragoverTimer);
        }
        $("body").addClass("jqFileUploadDragging");
        self.dragoverTimer = window.setTimeout(function() {
          self.dragoverTimer = null;
          $("body").removeClass("jqFileUploadDragging");
        }, 1000);
      },
      drop: function() {
        if (self.dragoverTimer) {
          window.clearTimeout(self.dragoverTimer);
        }
        self.dragoverTimer = null;
        $("body").removeClass("jqFileUploadDragging");
      },
      done: function(e, data) {
        $.map(data.result, function(val) {
          self.uploadedFiles.push(val.fileName);
        });
      },
      fail: function(e, data) {
        $.unblockUI();
        //console.log("upload failed:",data.error);
        $.pnotify({
          text: $.i18n("Error: %msg%", {msg: data.error.message}),
          type: "error"
        });
      }
    });
   
    // prevent default browser drop event
    $(document).bind('drop dragover', function (e) {
      e.preventDefault();
    });

    //console.log("init'ed fileupload on",this);
  }; 

  FileUploadButton.prototype.formatBitrate =  function (bits) {
    if (typeof bits !== 'number') {
        return '';
    }
    if (bits >= 1000000000) {
        return (bits / 1000000000).toFixed(2) + ' Gbit/s';
    }
    if (bits >= 1000000) {
        return (bits / 1000000).toFixed(2) + ' Mbit/s';
    }
    if (bits >= 1000) {
        return (bits / 1000).toFixed(2) + ' kbit/s';
    }
    return bits.toFixed(2) + ' bit/s';
  };

  FileUploadButton.prototype.renderExtendedProgress = function (data) {
    var self = this;
    return self.formatBitrate(data.bitrate);
  };

  // A plugin wrapper around the constructor, 
  // preventing against multiple instantiations 
  $.fn.fileUploadButton = function (opts) { 
    return this.each(function () { 
      if (!$.data(this, "fileUploadButton")) { 
        $.data(this, "fileUploadButton", new FileUploadButton(this, opts)); 
      } 
    }); 
  };

  // Enable declarative widget instanziation 
  $(function() {
      $(".jqFileUploadButton:not(.jqFileUploadButtonInited)").livequery(function() {
        $(this).fileUploadButton().addClass("jqFileUploadButtonInited");
      });
  });
})(jQuery);

