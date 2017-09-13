/* WARNING: THIS IS A DERIVED FILE. DON'T MODIFIY. */
/*

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

(c)opyright 2010-2017 Michael Daum http://michaeldaumconsulting.com

are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

*/

"use strict";
(function($) {

  if (typeof($.detectOS) === 'undefined') {
    $.detectOS = {
      Windows: (-1 !== navigator.platform.indexOf("Win")),
      MacOS: (-1 !== navigator.platform.indexOf("Mac")),
      Linux: (-1 !== navigator.platform.indexOf("Linux")),
      Unix: (-1 !== navigator.platform.indexOf("X11")),
      OS: null
    };

    if ($.detectOS.Windows) {
      $.detectOS.OS = "Windows";
    } else if ($.detectOS.Linux) {
      $.detectOS.OS = "Linux";
    } else if ($.detectOS.MacOS) {
      $.detectOS.OS = "MacOS";
    } else if ($.detectOS.UNIX) {
      $.detectOS.OS = "Unix";
    }
  }

}(jQuery));
/*

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

(c)opyright 2010-2017 Michael Daum http://michaeldaumconsulting.com

are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

*/

"use strict";
(function($) {

  function getOfficeUrl(url, officeSuite) {
    var schema;

    if (officeSuite === 'msoffice') {
      schema = getMsOfficeSchema(url) + ':ofe|u|';
      url = schema + url.replace(/^.*:/, window.location.protocol);
    } else if (officeSuite === 'libreoffice') {
      schema = 'vnd.sun.star.webdav:';
      url = url.replace(/^.*:/, schema);
    }

    return url;
  }

  function getExtension(url) {
    var i = url.indexOf("?"), a;
    if (i > -1) {
      url = url.substr(0, i);
    }
    a = url.split(".");
    if (a.length === 1) {
      return "";
    }
    return a.pop();
  }

  function getMsOfficeSchema(url) {
    var ext = getExtension(url).toLowerCase();

    switch (ext) {
      case "docx":
      case "doc":
      case "docm":
      case "dot":
      case "dotm":
      case "dotx":
      case "odt":
        return "ms-word";
      case "xltx":
      case "xltm":
      case "xlt":
      case "xlsx":
      case "xlsm":
      case "xlsb":
      case "xls":
      case "xll":
      case "xlam":
      case "xla":
      case "ods":
        return "ms-excel";
      case "pptx":
      case "pptm":
      case "ppt":
      case "ppsx":
      case "ppsm":
      case "pps":
      case "ppam":
      case "ppa":
      case "potx":
      case "potm":
      case "pot":
      case "odp":
        return "ms-powerpoint";
      case "accdb":
      case "mdb":
        return "ms-access";
      case "xsn":
      case "xsf":
        return "ms-infopath";
      case "pub":
        return "ms-publisher";
      case "vstx":
      case "vstm":
      case "vst":
      case "vssx":
      case "vssm":
      case "vss":
      case "vsl":
      case "vsdx":
      case "vsdm":
      case "vsd":
      case "vdw":
        return "ms-visio";
      case "mpp":
      case "mpt":
        return "ms-project";
      default:
        return "";
    }
  }

  // add webdav behavior
  $(function() {
    $(".jqWebDAVLink").livequery(function() {
      var $this = $(this);

      // special treatment for windows and macos; linux can handle this on its own using xdg
      if ($.detectOS.Windows || $.detectOS.MacOS) {
        $this.on("click", function() {
          var $this = $(this), 
              url = getOfficeUrl($this.attr("href"), foswiki.getPreference("TopicInteractionPlugin").officeSuite || 'msoffice');

          $("<iframe />").attr("src", url).appendTo("body");

          return false;
        });
      } 

    });
  });

}(jQuery));
/*

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

(c)opyright 2017 Michael Daum http://michaeldaumconsulting.com

are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

*/

/*eslint-disable no-console */

"use strict";
var Dialog;

(function($) {

  var defaults = {
    "template": "metadata",
    "debug": false
  };

  /* constructor **********************************************************/
  Dialog = function(opts) {
    var self = this;

    self.opts = $.extend({}, defaults, opts);
  };

  /* shortcut *************************************************************/
  Dialog.load = function(opts) {
    var dialog = new Dialog(opts);
    return dialog.load();
  };

  /* logger ***************************************************************/
  Dialog.prototype.log = function() {
    var self = this, args;

    if (!console || !self.opts.debug) {
      return;
    }

    args = $.makeArray(arguments);
    args.unshift("DIALOG:");
    console.log.apply(console, args);
  };


  /* load *****************************************************************/
  Dialog.prototype.load = function(params) {
    var self = this, 
        opts = $.extend({}, self.opts, params),
        $dialog = typeof(opts.id) === 'undefined'?undefined:$(opts.id),
        data, 
        dfd = $.Deferred();

    self.log("called load() opts=",opts);

    function callback(elem) {
      if (typeof(opts.init) === 'function') {
        opts.init.call(elem);
      }
    }

    if ($dialog && $dialog.length) {
      $dialog.dialog("open");
      $dialog.find("form").resetForm();
      callback($dialog);
      dfd.resolve($dialog);
    } else {

      data = $.extend({}, opts.data, {
        name: opts.template,
        expand: opts.expand,
        topic: foswiki.getPreference("WEB")+"."+foswiki.getPreference("TOPIC")
      });

      $.ajax({
        url: foswiki.getScriptUrl("rest", "RenderPlugin", "template"),
        data: data,
        dataType: 'html',
        success: function(data) {
          var $dialog = $(data);
          $dialog.on("dialogopen", function() {
            callback($dialog);
            dfd.resolve($dialog);
          });
          $dialog.appendTo("body");
        },
        error: function(xhr, status, err) {
          dfd.reject($dialog, status, err);
        }
      });
    }

    return dfd.promise();
  };
})(jQuery);
/*

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

(c)opyright 2010-2017 Michael Daum http://michaeldaumconsulting.com

are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

*/

/*eslint-disable no-console */
"use strict";
(function($) {

  var defaults = {
    "showHidden": false,
    "showOptions": false,
    "showEmpty": false,
    "sort": "name",
    "filter": "",
    "limit": 6,
    "skip": 0,
    "cols": 1,
    "debug": false
  };

  /* The actual plugin constructor ****************************************/
  function FoswikiAttachments(elem, opts) { 
    var self = this;

    self.elem = $(elem); 
    self.opts = $.extend({}, defaults, self.elem.data(), opts); 
    self.init(); 
  } 

  /* logger ***************************************************************/
  FoswikiAttachments.prototype.log = function() {
    var self = this, args;

    if (!console || !self.opts.debug) {
      return;
    }

    args = $.makeArray(arguments);
    args.unshift("FA:");
    console.log.apply(console, args);
  };

  /* init attachments *****************************************************/
  FoswikiAttachments.prototype.init = function () { 
    var self = this, tabpane;

    self.log("called init()");

    self.container = self.elem.parent();
    self.optionsButton = self.elem.find(".foswikiAttachmentsOptionsToggle");
    self.optionsLabel = self.optionsButton.find("span:last") || self.optionsButton;
    self.toggleContainer = self.elem.find(".foswikiAttachmentsOptionsToggleContainer");
    self.toggleOpts = $.extend({}, self.optionsButton.metadata(), self.optionsButton.data());
    self.pager = self.elem.find(".foswikiAttachmentsPager");

    self.selection = [];
    if (typeof(self.opts.selection) !== 'undefined' && self.opts.selection !== "") {
      self.selection = self.opts.selection.split(/\s*,\s*/);
    }

    self.elem.parent().parent().parent().each(function() {
      tabpane = $(this).data("tabPane");
    });

    if (self.opts.showEmpty || self.getCount() > 0) {
      self.elem.find(".foswikiAttachmentsSelectAll").show();
      if (tabpane) {
        tabpane.showTab(".attachments");
        if (tabpane.elem.find(">.jqTab").length === 1) {
          tabpane.switchTab(".attachments");
        }
      }
    } else {
      if (tabpane) {
        tabpane.hideTab(".attachments");
      }
    }

    self.displayAttachmentsCount();
    self.showSelection();

    // add listener for refresh event
    self.elem.bind("refresh", function(e, files) {
      self.log("got refresh event");
      if (files) {
        self.log("refreshing from files",files);
        self.clearSelection();
        $.each(files, function(i, file) {
          if (typeof(file) === 'string') {
            self.select(file);
          } else {
            self.select(file.name);
          }
        });
      }
      self.load();
      return false;
    });

    // add toggle behaviour
    self.optionsButton.click(function() {
      if (self.toggleContainer.is(":visible")) {
        self.hideOptionsContainer();
      } else {
        self.showOptionsContainer();
      }
      return false;
    });

    // add display hidden behaviour
    self.elem.find(".foswikiDisplayHidden input").change(function() {
      self.load({
        "showempty": true,
        "showhidden": $(this).prop('checked')
      });
      return false;
    });

    // add behaviour to filter
    self.elem.find(".foswikiFilter input").bind("keypress", function(event) {
      var $input = $(this), val;

      if(event.keyCode === 13) {
        val = $input.val();
        if (val === 'none') {
          val = '';
        } 
        self.load({
          "showempty": true,
          "filter": val
        });
        event.preventDefault();
        return false;
      }
    });

    // add sort behaviour
    self.elem.find(".foswikiSortBy select").change(function() {
      var $this = $(this);

      self.load({
        "skip":0,
        "sort": $this.val()
      });

      return false;
    });


    // add limit behaviour
    self.elem.find(".foswikiResultsPerPage select").change(function() {
      var $this = $(this);

      self.load({
        "skip": 0,
        "limit": $this.val()
      });
      return false;
    });

    // add pager behaviour
    self.pager.find("a").click(function() {
      var $this = $(this);

      self.load({
        "skip": self.getSkip($this)
      });
      return false;
    });

    // add attachment behaviour
    self.elem.find(".foswikiAttachment").hover(
      function() {
        $(this).addClass("foswikiAttachmentHover");
      },
      function() {
        $(this).removeClass("foswikiAttachmentHover");
      }
    ).click(function(e) {
      var $attachment = $(this), 
          id = decodeURIComponent($attachment.attr('id'));

      if (!$(e.target).is("a,img")) { // dont propagate the attachment clicks
        $attachment.toggleClass("foswikiAttachmentSelected");

        if ($attachment.hasClass("foswikiAttachmentSelected")) {
          self.select(id);
        } else {
          self.clear(id);
        }
        e.stopPropagation();
        return false;
      }
    });

    // add select all behaviour
    self.elem.find(".foswikiAttachmentsSelectAll").click(function() {
      //self.log("clicked select all");
      self.selection = [];
      self.elem.find("input.foswikiAttachmentsAll").each(function() {
        self.selection.push($(this).val());
      });
      $(this).hide();
      self.showSelection();
      return false;
    });

    // add clear all behaviour
    self.elem.find(".foswikiAttachmentsClearAll").click(function() {
      self.clearSelection();
      self.elem.find(".foswikiAttachmentsSelectAll").show();
      return false;
    });

    // add preview behaviour
    self.elem.find(".foswikiAttachmentPreviewButton").click(function() {
      var $button = $(this),
          $attachment = $button.parents(".foswikiAttachment:first"),
          attachmentOpts = $attachment.data(),
          extension = attachmentOpts.filename.replace(/^.+\./, ''),
          previewType;

      if (extension.match(/mp3|wav/)) {
        previewType = "audio";
      } else if (extension.match(/flv|swf|mp4|mpe?g|mov|ogg|webm|ogv/)) { 
        previewType = "video";
      } else if (extension.match(/vsd/)) {
        previewType = "visio";
      } else {
        previewType = "document";
      }

      $.blockUI({
        message:"<h1>"+$.i18n("Loading preview ...")+"</h1>",
        fadeIn: 0,
        fadeOut: 0
      });

      Dialog.load({
        expand: "attachments::previewer::"+previewType, 
        data: {
          filename: decodeURIComponent(attachmentOpts.filename)
        }
      }).done(function($dialog) {
        $.unblockUI();
        $dialog.parent().find(".ui-dialog-title").text(decodeURIComponent(attachmentOpts.filename));
      });

      return false;
    });

    // add delete button behaviour
    self.elem.find(".foswikiAttachmentDeleteButton").click(function() {
      var $button = $(this),
          $attachment = $button.parents(".foswikiAttachment:first"),
          attachmentOpts = $attachment.data(),
          thumbnail = $attachment.find(".foswikiThumbnail").clone().removeClass("foswikiLeft");

      Dialog.load({
        id:"#foswikiAttachmentConfirmDelete", 
        expand:"attachments::confirmdelete",
        init: function() {
          var $this = this;

          $this.find("#deleteAttachment").text(decodeURIComponent(attachmentOpts.filename));
          $this.find("input[name=filename]").val(decodeURIComponent(attachmentOpts.filename));
          if (thumbnail.find(".foswikiAlert").length === 0) {
            $this.find(".foswikiThumbnailContainer").html(thumbnail);
          }

          $this.dialog("option", "position", "center");
        }
      });

      return false;
    });

    // edit behaviour
    self.elem.find(".foswikiAttachmentEditButton").click(function(ev) {
        ev.stopPropagation();
    });

    // add button behaviour 
    self.elem.find(".foswikiAttachmentPropertiesButton").click(function() {
      var $button = $(this),
          $attachment = $button.parents(".foswikiAttachment:first"),
          attachmentOpts = $attachment.data(),
          thumbnail = $attachment.find(".foswikiThumbnail").clone().removeClass("foswikiLeft");


      Dialog.load({
        id:"#foswikiAttachmentEditor", 
        expand:"attachments::editor", 
        init: function() {
          var $this = this;

          var $hideFile = $this.find("input[name=hidefile]"),
              $isThumbnail = $this.find("input[name=isthumbnail]");

          //self.log("show attachment editor");
          $this.find("input[name=origfilename]").val(decodeURIComponent(attachmentOpts.filename));
          $this.find("input[name=filename]").val(decodeURIComponent(attachmentOpts.filename));
          $this.find("input[name=filecomment]").val(decodeURIComponent(attachmentOpts.filecomment));
          if (thumbnail.find(".foswikiAlert").length === 0) {
            $this.find(".foswikiThumbnailContainer").html(thumbnail);
          }
          if (attachmentOpts.filename.match(/\.(gif|jpe?g|png|bmp|svg|tiff?)$/i)) {
            $this.find(".foswikiThumbnailStep").show();
          } else {
            $this.find(".foswikiThumbnailStep").hide();
          }
          if (attachmentOpts.fileattr.match(/h/)) {
            $hideFile.prop("checked", true);
          } else {
            $hideFile.prop("checked", false);
          }
          if (attachmentOpts.fileattr.match(/t/)) {
            $isThumbnail.prop("checked", true);
          } else {
            $isThumbnail.prop("checked", false);
          }
          $this.dialog("option", "position", "center");
        }
      });

      return false;
    });

    // add move button behaviour
    self.elem.find(".foswikiAttachmentMoveButton").click(function() {
      var $button = $(this),
          $attachment = $button.parents(".foswikiAttachment:first"),
          attachmentOpts = $attachment.data(),
          thumbnail = $attachment.find(".foswikiThumbnail").clone().removeClass("foswikiLeft");

      Dialog.load({
        id: "#foswikiAttachmentMove", 
        expand: "attachments::moveattachment",
        init: function() {
          var $this = this;

          $this.find("input[name=filename]").val(decodeURIComponent(attachmentOpts.filename));
          if (thumbnail.find(".foswikiAlert").length === 0) {
            $this.find(".foswikiThumbnailContainer").html(thumbnail);
          }
          $this.find(".foswikiGenericThumbnail").hide();
          
          $this.dialog("option", "position", "center");
        }
      });

      return false;
    });

    // add bulk action behaviour
    self.elem.find(".foswikiAttachmentsBulkAction select").change(function() {
      var $select = $(this),
          action = $select.val(), 
          msgClass,
          len = self.selection?self.selection.length:0;

      if (!len || !action) {
        return;
      }

      $select.val("");

      if (action === "createlink") {
        msgClass = ".foswikiAttachmentBulkCreateLinks";
      } else if (action === "createimagegallery") {
        msgClass = ".foswikiAttachmentBulkCreateImageGallery";
      } else if (action === "download") {
        msgClass = ".foswikiAttachmentBulkDownload";
      } else if (action === "hide") {
        msgClass = ".foswikiAttachmentBulkHide";
      } else if (action === "unhide") {
        msgClass = ".foswikiAttachmentBulkUnHide";
      } else if (action === "delete") {
        msgClass = ".foswikiAttachmentBulkDelete";
      } else if (action === "move") {
        /* use the moveattachment dialog */
      } else {
        alert("unknown action "+action);
        return;
      }

      if (action !== "move") {
        Dialog.load({
          id: "#foswikiAttachmentConfirmBulk", 
          expand: "attachments::confirmbulkaction",
          init: function() {
            var $this = this,
                $form = $this.find("form");

            $form.find("input[type='hidden'][name='filename']").remove();
            $.each(self.selection, function(i, val) {
              $("<input type='hidden' name='filename' />").val(val).prependTo($form);
            });
            $this.find("input[name='action']").val(action);
            $form.attr("action", foswiki.getScriptUrl("rest", "TopicInteractionPlugin", action));
            $this.find(".foswikiAttachmentBulkMessage").hide();
            $this.find(msgClass).show().find("b").text(len);

            $this.dialog("option", "position", "center");
          }
        });

      } else {
        // move attachments 
        Dialog.load({
          id: "#foswikiAttachmentMove", 
          expand: "attachments::moveattachment",
          init: function() {
            var $this = this,
                $form = $this.find("form");

            $form.find("input[type='hidden'][name='filename']").remove();
            $.each(self.selection, function(i, val) {
              $("<input type='hidden' name='filename' />").val(val).prependTo($form);
            });
            $this.find(".foswikiAttachmentsCount").text(self.selection.length);
            $this.find(".foswikiThumbnailContainer").empty();
            $this.find(".foswikiGenericThumbnail").show();

            $this.dialog("option", "position", "center");
          }
        });
      }
    });

    // add show more versions behaviour 
    self.elem.find(".foswikiShowVersions").each(function() {
      var $this = $(this),
          $attachment = $this.parents(".foswikiAttachment:first"),
          attachmentOpts = $attachment.data(),
          $versionContainer = $attachment.find(".foswikiVersionsContainer"),
          url = foswiki.getScriptUrl("rest", "RenderPlugin", "template", {
            "name": "metadata",
            "render": "on",
            "topic": self.opts.topic,
            "expand": "attachments::versions",
            "filename": attachmentOpts.filename
          });
      
      $this.click(function() {
        if($versionContainer.is(".foswikiVersionsContainerLoaded")) {
          $this.hide();
          $attachment.find(".foswikiHideVersions").show();
          $versionContainer.slideDown("fast");
        } else {
          $versionContainer.show();
          $versionContainer.load(url, function() {
            $versionContainer.addClass("foswikiVersionsContainerLoaded");
            $attachment.effect("highlight");
            $this.hide();
            $attachment.find(".foswikiHideVersions").show();
          });
        }
        return false;
      });
    });
   
    // add hide more versions behaviour 
    self.elem.find(".foswikiHideVersions").each(function() {
      var $this = $(this),
          $attachment = $this.parents(".foswikiAttachment:first"),
          $versionContainer = $attachment.find(".foswikiVersionsContainer");
      
      $this.click(function() {
        $this.hide();
        $attachment.find(".foswikiShowVersions").show();
        $versionContainer.slideUp("fast");
        return false;
      });
    });

    // ajaxify editor form
    $("#foswikiAttachmentEditorForm").livequery(function() {
      var $form = $(this);

      $form.ajaxForm({
        dataType:"json",
        beforeSubmit: function() {
          $form.parent().dialog("close");
          $.blockUI({
            message:"<h1>"+$.i18n("Saving changes ...")+"</h1>",
            fadeIn: 0,
            fadeOut: 0
          });
        },
        success: function() {
          $.unblockUI();
          self.load();
        },
        error: function(xhr, msg) {
          var data;
          try {
            data = $.parseJSON(xhr.responseText);
            msg = data.error.message;
          } catch(err) {
            // ignore
          }
          $.unblockUI();
          $.pnotify({
             title: $.i18n("Edit failed"),
             text: msg,
             type: 'error'
          });
        }
      });
    });

    // ajaxify delete confirm
    $("#foswikiAttachmentConfirmDeleteForm").livequery(function() {
      var $form = $(this), filename;

      $form.ajaxForm({
        dataType:"json",
        beforeSubmit: function() {
          $form.parent().dialog("close");
          filename = $form.find("input[name='filename']").val();
          $.blockUI({
            message:"<h1>"+$.i18n("Deleting %file% ...", {file: filename})+"</h1>",
            fadeIn: 0,
            fadeOut: 0
          });
        },
        success: function() {
          $.unblockUI();
          self.clear(filename);
          self.load();
        },
        error: function(xhr, msg) {
          var data;
          try {
            data = $.parseJSON(xhr.responseText);
            msg = data.error.message;
          } catch(err) {
            // ignore
          }
          $.unblockUI();
          $.pnotify({
             title: $.i18n("Failed to delete %file%", {file: filename}),
             text: msg,
             type: 'error'
          });
        }
      });
    });

    // ajaxify move attachment form
    $("#foswikiAttachmentMoveForm").livequery(function() {
      var $form = $(this);

      $form.ajaxForm({
        dataType:"json",
        beforeSubmit: function() {
          $form.parent().dialog("close");
          $.blockUI({
            message:"<h1>"+$.i18n("Moving attachment(s) ...")+"</h1>",
            fadeIn: 0,
            fadeOut: 0
          });
        },
        success: function() {
          $.unblockUI();
          self.clearSelection();
          self.load();
        },
        error: function(xhr, msg) {
          var data;
          try {
            data = $.parseJSON(xhr.responseText);
            msg = data.error.message;
          } catch(err) {
            // ignore
          }
          $.unblockUI();
          $.pnotify({
             title: $.i18n("Move failed"),
             text: msg,
             type: 'error'
          });
        }
      });
    });

    // ajaxify bulk action form
    $("#foswikiAttachmentConfirmBulkForm").livequery(function() {
      var $form = $(this), msgText, action;

      $form.ajaxForm({
        dataType:"json",
        beforeSubmit: function() {
          msgText = $form.find(".foswikiAttachmentBulkMessage:visible .foswikiAttachmentBulkProgressMessage").html();
          action = $form.find("input[name='action']").val();
          $form.parent().dialog("close");
          $.blockUI({
            message:"<h1>"+msgText+" ...</h1>",
            fadeIn: 0,
            fadeOut: 0
          });
        },
        success: function(data) {
          $.unblockUI();
          // perform reload
          if (action === "createlink" || action === "createimagegallery") {
            //self.log("reloading topic");
            window.location.href = foswiki.getScriptUrl("view", foswiki.getPreference("WEB"), foswiki.getPreference("TOPIC"));
          } 
          
          // perform redirect
          else if (action === "download") {
            //self.log("redirect url="+data.result);
            window.location.href = data.result;
          } 

          // clear selection
          else if (action === 'delete') {
            self.clearSelection();
            self.load();
          }
          
          // default
          else {
            self.load();
          }
        },
        error: function(xhr, msg) {
          var data;
          try {
            data = $.parseJSON(xhr.responseText);
            msg = data.error.message;
          } catch(err) {
            // ignore
          }
          $.unblockUI();
          $.pnotify({
             title: $.i18n("Error during '%action%'", {action: action}),
             text: msg,
             type: 'error'
          });
        }
      });
    });
    
  };  // end of init()

  /* get number of attachments ********************************************/
  FoswikiAttachments.prototype.getCount = function() {
    var self = this;

    return (self.pager.length)?self.pager.data("count"):0;
  };

  /* get current skip *****************************************************/
  FoswikiAttachments.prototype.getSkip = function(elem) {
    var self = this;

    elem = elem || self.pager.find("a.current");

    return (elem.length)?elem.data("skip"):0;
  };

  /* display number of attachments ****************************************/
  FoswikiAttachments.prototype.displayAttachmentsCount = function() {
    var self = this,
        n = self.getCount();

    // set counter
    if (n) {
      self.elem.parents(".foswikiMetaData:first").find(".foswikiAttachmentsCount").text("("+n+")").show();
    } else {
      self.elem.parents(".foswikiMetaData:first").find(".foswikiAttachmentsCount").text("").hide();
    }

    return n;
  };

  /* all attachments *************************************************/
  FoswikiAttachments.prototype.load = function(params) {
    var self = this, 
        url, thisParams = {};

    self.log("called load()");

    $.each(params, function(key, val) {
      thisParams["attachments_"+key] = val;  
    });

    params = $.extend({
      "name": "metadata",
      "render": "on",
      "topic": self.opts.topic,
      "expand": "attachments",
      "attachments_showhidden": self.opts.showHidden,
      "attachments_showoptions": self.opts.showOptions,
      "attachments_showempty": self.opts.showEmpty,
      "attachments_sort": self.opts.sort,
      "attachments_reverse": self.opts.sort === 'date' ? true: false,
      "attachments_filter": encodeURI(self.opts.filter),
      "attachments_limit": self.opts.limit,
      "attachments_skip": self.getSkip(),
      "attachments_cols": self.opts.cols,
      "attachments_selection": []
    }, thisParams);

    $.each(self.selection, function(i, item) {
      params["attachments_selection"].push(encodeURIComponent(item.replace(/\\\./, '.')));
    });

    //self.log("params=",params);

    url = foswiki.getScriptUrl("rest", "RenderPlugin", "template", params);

    self.elem.block({
      message:null,
      fadeIn: 0,
      fadeOut: 0,
      overlayCSS: {
        cursor:'progress'
      }
    });

    self.container.load(url, function() {
      self.elem.unblock();
      self.container.height('auto');
      self.elem.removeData("FoswikiAttachments"); // remove reference 
    });
  };

  /* mark current selection **********************************************/
  FoswikiAttachments.prototype.showSelection = function() {
    var self = this, i, id;

    self.elem.find(".foswikiAttachmentSelected").removeClass("foswikiAttachmentSelected");
    if (self.selection) {
      for (i = 0; i < self.selection.length; i++) {
        id = encodeURIComponent(self.selection[i]);
        // jQuery can't handle id's with umlauts in it
        //$("#"+id).addClass("foswikiAttachmentSelected");
        $(document.getElementById(id)).addClass("foswikiAttachmentSelected");
      }
      if (self.selection.length) {
        self.elem.find(".foswikiAttachmentsBulkAction, .foswikiAttachmentsClearAll").show();
        self.elem.find(".foswikiAttachmentsSelected").text(self.selection.length);
      } else {
        self.elem.find(".foswikiAttachmentsBulkAction, .foswikiAttachmentsClearAll").hide();
      }
    } else {
      self.elem.find(".foswikiAttachmentsBulkAction, .foswikiAttachmentsClearAll").hide();
    }
  };

  /* add an id to the selection ******************************************/
  FoswikiAttachments.prototype.select = function(id) {
    var self = this;

    if (!id) {
      return;
    }

    //self.log(" select("+id+")");
    if (typeof(self.selection) === 'undefined') {
      self.selection = [];
    }
    self.selection.push(id);
    if (self.selection.length === self.getCount()) {
      self.elem.find(".foswikiAttachmentsSelectAll").hide();
    }
    self.showSelection();
  };

  /* remove an id from the selection *************************************/
  FoswikiAttachments.prototype.clear = function(id) {
    var self = this;

    if (self.selection) {
      for (var i = 0; i < self.selection.length; i++) {
        if (self.selection[i] === id) {
          self.selection.splice(i, 1);
          break;
        }
      }
    }
    self.elem.find(".foswikiAttachmentsSelectAll").show();
    self.showSelection();
  };

  /* empty the selection *************************************************/
  FoswikiAttachments.prototype.clearSelection = function()  {
    var self = this;

    self.selection = [];
    self.showSelection();
  };

  /***********************************************************************/
  FoswikiAttachments.prototype.hideOptionsContainer = function() {
    var self = this;

    self.optionsLabel.html($.i18n("Show options"));
    self.toggleContainer.slideUp({easing:'easeInOutQuad', duration:'fast'});
    self.opts.showOptions = false;
  };

  /***********************************************************************/
  FoswikiAttachments.prototype.showOptionsContainer = function() {
    var self = this;

    self.optionsLabel.html($.i18n("Hide options"));
    self.toggleContainer.slideDown({easing:'easeInOutQuad', duration:'fast'});
    self.opts.showOptions = true;
  };

  /* init attachments tab *************************************************/
  $(function() {
    $(".foswikiAttachments.foswikiFormSteps:not(.foswikiInitedAttachments)").livequery(function() {
      var $this = $(this);

      if (typeof($this.data("foswikiAttachments")) === 'undefined') {
        $this.data("foswikiAttachments", new FoswikiAttachments(this));
      }

      $this.addClass("foswikiInitedAttachments");
    }); /** end of livequery for foswikiAttachments **/
  });
}(jQuery));
