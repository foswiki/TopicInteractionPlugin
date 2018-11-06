/*
 * foswiki file upload plugin 2.0
 *
 * Copyright (c) 2016-2018 Michael Daum http://michaeldaumconsulting.com
 *
 * Licensed GPL http://www.gnu.org/licenses/gpl.html
 *
 */

/* global Dialog, window */

"use strict";
(function($) {

  // uploader defaults
  var defaults = {
    topic: null,
    progress: null
  };

  // The file upload class ///////////////////////////////////////////////////
  function FoswikiUploader(elem, opts) {
    var self = this;

    self.elem = $(elem);
    self.opts = $.extend({}, defaults, self.elem.data(), opts);
    self.init();
  }

  FoswikiUploader.prototype.init = function () {
    var self = this;

    self.uploadedFiles = [];

    // create workhorse
    self.elem.fileupload({
      url: foswiki.getScriptUrl("rest", "TopicInteractionPlugin", "upload"),
      fileInput: null,
      dataType: 'json',
      pasteZone: $(document),
      sequentialUploads: true,
      singleFileUploads: true,
      replaceFileInput: false,
      progress: function(e, data) {
        var files = [];
        $.each(data.files, function(index, file) {
          files.push(file.name);
        });
        self.progressBar.add(files);
      },
      progressall: function (e, data) {
        var progress = parseInt(data.loaded / data.total * 100, 10);
        self.progressBar.setProgress(progress);
      },
      add: function(e, data) {
        data.files = data.files;
        data.formData = self.opts;
        data.formData.id = Math.ceil(Math.random()*1000);
        data.submit();
      },
      paste: function(e, data) {
        if (typeof(data.files) !== 'undefined' && data.files.length) {
          self.currentData = data;

          Dialog.load({
            id:"#foswikiAttachmentPaste",
            expand:"attachments::paste",
            init: function() {
              if (typeof(self.prevFileName) !== 'undefined') {
                this.find("input[name='filename']").val(self.prevFileName);
              }
            },
            data: {
              filename: "clipboard"
            }
          }).done(function($dialog) {
            $dialog.find("form:not(.inited)").addClass("inited").submit(function() {
              var fileName = $dialog.find("input[name='filename']").val();

              if (fileName) {
                if (self.currentData.files.length > 1) {
                  $.each(self.currentData.files, function(index, file) {
                    file.uploadName = fileName + index;
                    self.prevFileName = file.uploadName;
                  });
                } else {
                    self.currentData.files[0].uploadName = fileName;
                    self.prevFileName = fileName;
                }
                self.add(self.currentData);

                self.currentData = undefined;
              }
              $dialog.dialog("close");
              return false;
            });
          });
          return false;
        }
      },
      start: function() {
        self.uploadedFiles = [];
        self.progressBar.start();
      },
      dragover: function() {
        if (self.dragoverTimer) {
          window.clearTimeout(self.dragoverTimer);
        }
        self.elem.addClass("jqUploadDragging");
        self.dragoverTimer = window.setTimeout(function() {
          self.dragoverTimer = null;
          self.elem.removeClass("jqUploadDragging");
        }, 1000);
      },
      drop: function() {
        if (self.dragoverTimer) {
          window.clearTimeout(self.dragoverTimer);
        }
        self.dragoverTimer = null;
        self.elem.removeClass("jqUploadDragging");
      },
      done: function(e, xhr) {
        var data = xhr.result;
        $.map(data.result, function(val) {
          self.uploadedFiles.push(val.fileName);
        });
      },
      stop: function() {
        self.progressBar.stop();
        $.pnotify({
          text: $.i18n("Uploaded %num% file(s)", {num: self.uploadedFiles.length}),
          type: "success",
          delay: 1000
        });
        $(".foswikiAttachments").trigger("refresh", [self.uploadedFiles]); // legacy
        self.elem.trigger("afterUpload", [self.uploadedFiles]);
      },
      fail: function(e, data) {
        var response = data.jqXHR.responseJSON || { error: { message: "unknown error"} };
        //console.log("upload failed:",response.error.message);
        $.pnotify({
          text: $.i18n("Error: %msg%", {msg: response.error.message}),
          type: "error"
        });
      }
    });

    // prevent default browser drop event
    $(document).bind('drop dragover', function (e) {
      e.preventDefault();
      return false;
    });

    // attach to progress bar object
    self.progressBar = self.elem.data("uploadProgress");

    //console.log("init'ed fileupload on",this);
  };

  FoswikiUploader.prototype.add = function (params) {
    var self = this;

    self.elem.fileupload("add",params);
  };

  FoswikiUploader.prototype.send = function (params) {
    var self = this;

    params.formData = self.opts;
    params.formData.id = Math.ceil(Math.random()*1000);

    return self.elem.fileupload("send",params);
  };

  // The file upload button class //////////////////////////////////////
  function UploadButton(elem, opts) {
    var self = this;

    self.elem = $(elem);
    self.opts = $.extend({}, self.elem.data(), opts);
    self.init();
  }

  UploadButton.prototype.init = function () {
    var self = this;

    self.elem.on("change", function() {
      /*
      self.send().done(function(data) {
        console.log("done button with result.",data.result);
      });
      */
      self.add();
    });
  };

  UploadButton.prototype.add = function () {
    var self = this;

    return foswiki.uploader.add({
      fileInput: self.elem.find("input[type=file]")
    });
  };

  UploadButton.prototype.send = function () {
    var self = this;

    return foswiki.uploader.send({
      fileInput: self.elem.find("input[type=file]")
    });
  };

  // The upload indicator class ///////////////////////////////////////////////////
  function UploadProgress(elem) {
    var self = this;

    self.bar = $('<div class="jqUploadProgressBar"><span class="i18n">Uploading ...</span><span class="jqUploadProgressInfo"></span></div>').appendTo(elem);
    self.progressInfo = self.bar.find(".jqUploadProgressInfo");
    self.dropIndicator = $('<div class="jqUploadIndicator"><span class="i18n">Drag files here.</span></div>').appendTo(elem);
    self.reset();
  }

  UploadProgress.prototype.reset = function () {
    var self = this;

    self.setProgress(0);
    self.progressInfo.html("");
  };

  UploadProgress.prototype.add = function (files) {
    var self = this;
    self.progressInfo.html(files.join(", "));
  };

  UploadProgress.prototype.setProgress = function(val) {
    var self = this;

    self.progress = val;
    self.bar.css("width", val+"%");
    //console.log("setProgress",val);
  };

  UploadProgress.prototype.getProgress = function() {
    var self = this;

    return self.progress;
  };

  UploadProgress.prototype.start = function() {
    var self = this;

    self.reset();
    $.blockUI({
      blockMsgClass: "jqUploadMsg",
      message: self.bar
    });
  };

  UploadProgress.prototype.stop = function() {
    var self = this;

    $.unblockUI();
    self.reset();
  };

  /////////////////////////////////////////////////////////////////////////////

  // preventing against multiple instantiations
  $.fn.uploadButton = function(opts) {
    return this.each(function () {
      if (!$.data(this, "uploadButton")) {
        $.data(this, "uploadButton", new UploadButton(this, opts));
      }
    });
  };

  $.fn.uploadProgress = function(opts) {
    return this.each(function () {
      if (!$.data(this, "uploadProgress")) {
        $.data(this, "uploadProgress", new UploadProgress(this, opts));
      }
    });
  };

  $.fn.foswikiUploader = function(opts) {
    return this.each(function () {

      // create one instance for use by other components such as the UploadButton
      if (!foswiki.uploader) {
        foswiki.uploader = new FoswikiUploader(this, opts);
      }
    });
  };

  // Enable declarative widget instanziation
  $(function() {

      // set defaults
      defaults.topic = foswiki.getPreference("WEB")+"."+foswiki.getPreference("TOPIC");

      // create progress bar for uploads
      $("body").uploadProgress();

      // create foswiki uploader
      $("body").foswikiUploader();

      // create upload buttons
      $(".jqUploadButton:not(.jqUploadButtonInited)").livequery(function() {
        $(this).uploadButton().addClass("jqUploadButtonInited");
      });

  });
})(jQuery);
