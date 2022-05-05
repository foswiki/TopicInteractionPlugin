/*

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

(c)opyright 2010-2022 Michael Daum http://michaeldaumconsulting.com

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

/* global Dialog, window */

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
    self.log("new FoswikiAttachments opts=",self.opts);
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
      $.each(self.opts.selection.split(/\s*,\s*/), function(i, id) {
	if (typeof(self.getAttachmentData(id)) !== 'undefined') {
	  self.select(id);
	}
      });
    }

    self.elem.parent().parent().parent().each(function() {
      tabpane = $(this).data("tabPane");
    });

    if (tabpane) {
      if (self.opts.showEmpty || self.getCount() > 0) {
        self.elem.find(".foswikiAttachmentsSelectAll").show();
        tabpane.showTab(".attachments");
        if (tabpane.elem.find(">.jqTab").length === 1) {
          tabpane.switchTab(".attachments");
        }
      } else {
        tabpane.hideTab(".attachments");
      }
    }

    self.displayAttachmentsCount();
    self.showSelection();

    // add listener for refresh event
    self.elem.on("refresh", function(e, files) {
      self.log("got refresh event");
      if (files) {
        self.log("refreshing from files",files);
        self.clearSelection();
        $.each(files, function(i, file) {
          if (typeof(file) === 'string') {
            self.select(file, true);
          } else {
            self.select(file.name, true);
          }
        });
      }
      self.load();
      return false;
    });

    // add toggle behaviour
    self.optionsButton.on("click", function() {
      if (self.toggleContainer.is(":visible")) {
        self.hideOptionsContainer();
      } else {
        self.showOptionsContainer();
      }
      return false;
    });

    // add display hidden behaviour
    self.elem.find(".foswikiDisplayHidden input").on("change", function() {
      self.load({
        "showempty": true,
        "showhidden": $(this).prop('checked')
      });
      return false;
    });

    // add behaviour to filter
    self.elem.find(".foswikiFilter input").on("keypress", function(event) {
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
    self.elem.find(".foswikiSortBy select").on("change", function() {
      var $this = $(this), val = $this.val();

      self.load({
        "skip":0,
        "sort": val,
        "reverse": val === 'date' ? true : false
      });

      return false;
    });


    // add limit behaviour
    self.elem.find(".foswikiResultsPerPage select").on("change", function() {
      var $this = $(this);

      self.load({
        "skip": 0,
        "limit": $this.val()
      });
      return false;
    });

    // add pager behaviour
    self.pager.find("a").on("click", function() {
      var $this = $(this);

      self.load({
        "skip": self.getSkip($this)
      });
      return false;
    });

    // add attachment behaviour
    self.elem.find(".foswikiAttachment").on("mouseenter",
    function() {
      $(this).addClass("foswikiAttachmentHover");
    }).on("mouseleave", function() {
      $(this).removeClass("foswikiAttachmentHover");
    }).on("click", function(e) {
      var $attachment = $(this),
          id = $attachment.data('id');

      if (!$(e.target).is("a,img,i")) { // dont propagate the attachment clicks
        $attachment.toggleClass("foswikiSelected");

        if ($attachment.hasClass("foswikiSelected")) {
          self.select(id);
        } else {
          self.clear(id);
        }
        e.stopPropagation();
        return false;
      }
    }).find(".foswikiAttachmentSelect").on("click", function(e) {
      var $attachment = $(this).parents(".foswikiAttachment:first"),
          id = $attachment.data('id');

      $attachment.toggleClass("foswikiSelected");

      if ($attachment.hasClass("foswikiSelected")) {
        self.select(id);
      } else {
        self.clear(id);
      }
      e.stopPropagation();
      return false;

    });

    // add select all behaviour
    self.elem.find(".foswikiAttachmentsSelectAll").on("click", function() {
      self.log("clicked select all");
      self.selection = [];
      self.elem.find("input.foswikiAttachmentsAll").each(function() {
        self.selection.push($(this).data("id"));
      });
      $(this).hide();
      self.showSelection();
      return false;
    });

    // add clear all behaviour
    self.elem.find(".foswikiAttachmentsClearAll").on("click", function() {
      self.clearSelection();
      self.elem.find(".foswikiAttachmentsSelectAll").show();
      return false;
    });

    // add preview behaviour
    self.elem.find(".foswikiAttachmentPreviewButton").on("click", function() {
      var $button = $(this),
          $attachment = $button.parents(".foswikiAttachment:first"),
          attachmentOpts = self.getAttachmentData($attachment),
          extension = attachmentOpts.filename.replace(/^.+\./, ''),
          previewType;

      if (extension.match(/mp3|wav/)) {
        previewType = "audio";
      } else if (extension.match(/mp4|mpe?g|mov|ogg|webm|ogv/)) {
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
    self.elem.find(".foswikiAttachmentDeleteButton").on("click", function() {
      var $button = $(this),
          $attachment = $button.parents(".foswikiAttachment:first"),
          attachmentOpts = self.getAttachmentData($attachment),
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
    self.elem.find(".foswikiAttachmentEditButton").on("click", function(ev) {
        ev.stopPropagation();
    });

    // add button behaviour
    self.elem.find(".foswikiAttachmentPropertiesButton").on("click", function() {
      var $button = $(this),
          $attachment = $button.parents(".foswikiAttachment:first"),
          attachmentOpts = self.getAttachmentData($attachment),
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
          if (attachmentOpts.filename.match(/\.(gif|jpe?g|png|bmp|svg|webp|pdf|tiff?)$/i)) {
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
    self.elem.find(".foswikiAttachmentMoveButton").on("click", function() {
      var $button = $(this),
          $attachment = $button.parents(".foswikiAttachment:first"),
          attachmentOpts = self.getAttachmentData($attachment),
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

          if (attachmentOpts.movedFromName && 
              attachmentOpts.movedFromWeb && 
              attachmentOpts.movedFromTopic) {
            $this.find(".foswikiMovedFromStep").show();
          } else {
            $this.find(".foswikiMovedFromStep").remove();
          }
          $this.find(".foswikiMovedFromStep input[name=restore]:not(.inited)").addClass("inited").on("click", function() {
            var fileName, web, topic;

            if (this.checked) {
              fileName = (decodeURIComponent(attachmentOpts.movedFromName));
              web = decodeURIComponent(attachmentOpts.movedFromWeb);
              topic = decodeURIComponent(attachmentOpts.movedFromTopic);
            } else {
              fileName = decodeURIComponent(attachmentOpts.filename),
              web = decodeURIComponent(attachmentOpts.web);
              topic = decodeURIComponent(attachmentOpts.topic);
            }
            self.log("fileName=",fileName,"web=",web,"topic=",topic);

            $this.find("input[name=filename]").val(fileName);
            $this.find("input[name=newweb]").val(web);
            $this.find("input[name=newtopic]").val(topic);
          });

          $this.dialog("option", "position", "center");
        }
      });

      return false;
    });

    // add bulk action behaviour
    self.elem.find(".foswikiAttachmentsBulkAction select").on("change", function() {
      var $select = $(this),
          action = $select.val(),
          type = "", 
          msgClass,
          len = self.selection?self.selection.length:0;

      if (!len || !action) {
        return;
      }

      $select.val("");

      if (action === "createlink") {
        msgClass = ".foswikiAttachmentBulkCreateLinks";
        type = "file";
      } else if (action === "embed") {
        msgClass = ".foswikiAttachmentBulkEmbed";
        action = "createlink";
        type = "";
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
                $form = $this.find("form"),
                hiddenFlag = '';

            $form.find("input[type='hidden'][name='filename']").remove();
            $.each(self.selection, function(i, id) {
	      var attachmentOpts = self.getAttachmentData(id);
              if (typeof(attachmentOpts) !== 'undefined') {
                $("<input type='hidden' name='filename' />").val(decodeURIComponent(attachmentOpts.filename)).prependTo($form);
              }
              if (attachmentOpts.fileattr.match(/h/)) {
                if (hiddenFlag === '' || hiddenFlag === 'h') {
                  hiddenFlag = 'h';
                } else {
                  hiddenFlag = '?'
                }
              } else {
                if (hiddenFlag === '' || hiddenFlag === 'v') {
                  hiddenFlag = 'v';
                } else {
                  hiddenFlag = '?'
                }
              }
            });
            if (hiddenFlag === '?') {
              $this.find("input[name=hidefile]").parent().remove();
            } else if (hiddenFlag === 'h') {
              $this.find("input[name=hidefile]").prop("checked", true);
            } else if (hiddenFlag === 'v') {
              $this.find("input[name=hidefile]").prop("checked", false);
            }
            $this.find("input[name='action']").val(action);
            $this.find("input[name='type']").val(type);
            $form.attr("action", foswiki.getScriptUrl("rest", "TopicInteractionPlugin", action));
            $this.find(".foswikiAttachmentBulkMessage").hide();
            $this.find(msgClass).show().find(".count").text(len);

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
            $.each(self.selection, function(i, id) {
	      var attachmentOpts = self.getAttachmentData(id);
              if (typeof(attachmentOpts) !== 'undefined') {
                $("<input type='hidden' name='filename' />").val(decodeURIComponent(attachmentOpts.filename)).prependTo($form);
              }
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
          attachmentOpts = self.getAttachmentData($attachment),
          $versionContainer = $attachment.find(".foswikiVersionsContainer"),
          url = foswiki.getScriptUrl("rest", "RenderPlugin", "template"),
          params = {
            "name": "metadata",
            "render": "on",
            "topic": decodeURIComponent(self.opts.topic),
            "expand": "attachments::versions",
            "attachment": attachmentOpts.filename
          };

      $this.on("click", function() {
        if($versionContainer.is(".foswikiVersionsContainerLoaded")) {
          $this.hide();
          $attachment.find(".foswikiHideVersions").show();
          $versionContainer.slideDown("fast");
        } else {
          $versionContainer.show();
          $versionContainer.load(url, params, function() {
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

      $this.on("click", function() {
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
        beforeSerialize: function() {
          if (typeof(foswikiStrikeOne) !== 'undefined') {
            foswikiStrikeOne($form[0]);
          }
        },
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
        beforeSerialize: function() {
          if (typeof(foswikiStrikeOne) !== 'undefined') {
            foswikiStrikeOne($form[0]);
          }
        },
        beforeSubmit: function() {
          $form.parent().dialog("close");
          filename = $form.find("input[name='filename']").val();
          $.blockUI({
            message:"<h1>"+$.i18n("Deleting ...")+"</h1> <div class='noBreakout'>"+filename+"</div>",
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
        beforeSerialize: function() {
          if (typeof(foswikiStrikeOne) !== 'undefined') {
            foswikiStrikeOne($form[0]);
          }
        },
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
        beforeSerialize: function() {
          if (typeof(foswikiStrikeOne) !== 'undefined') {
            foswikiStrikeOne($form[0]);
          }
        },
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
          if (action === "createlink" || action === "createimagegallery" || action === 'embed') {
            //self.log("reloading topic");
            window.location.reload();
          }

          // perform redirect
          else if (action === "download") {
            //self.log("redirect url="+data.result);
            window.location.href = data.result;
          }

          // default
          else {
            self.clearSelection();
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

  /* get data of attachments **********************************************/
  FoswikiAttachments.prototype.getAttachmentData = function(elem) {
    var id;

    if (typeof(elem) === 'string')  {
      id = elem;
      elem = $(id);
    } else {
      id = elem.data("id");
    }

    return $("#data_"+id).data();
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
        url, thisParams = {},
        dfd = $.Deferred();

    self.log("called load()");

    $.each(params, function(key, val) {
      thisParams["attachments_"+key] = val;
    });

    params = $.extend({
      "name": "metadata",
      "render": "on",
      "cachecontrol": 0,
      "topic": decodeURIComponent(self.opts.topic),
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
      "attachments_selection": self.selection.join(", ")
    }, thisParams);

    //self.log("selection=",self.selection,"params=",params);

    url = foswiki.getScriptUrl("rest", "RenderPlugin", "template");

    self.elem.block({
      message:null,
      fadeIn: 0,
      fadeOut: 0,
      overlayCSS: {
        cursor:'progress'
      }
    });

    //self.log("loading from url=",url,"params=",params);
    self.container.load(url, params, function() {
      self.elem.unblock();
      self.container.height('auto');
      self.elem.removeData("FoswikiAttachments"); // remove reference
      dfd.resolve();
    });

    return dfd.promise();
  };

  /* mark current selection **********************************************/
  FoswikiAttachments.prototype.showSelection = function() {
    var self = this, i, id;

    self.log("showSelection", self.selection);

    self.elem.find(".foswikiSelected").removeClass("foswikiSelected");
    if (self.selection) {
      for (i = 0; i < self.selection.length; i++) {
        id = self.selection[i];
        $("#attachment_"+id).addClass("foswikiSelected");
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
  FoswikiAttachments.prototype.select = function(id, quiet) {
    var self = this;

    if (!id) {
      return;
    }

    id = id.replace(/[^0-9a-zA-Z_]/g, "_");

    //self.log(" select("+id+")");
    if (typeof(self.selection) === 'undefined') {
      self.selection = [];
    }
    self.selection.push(id);

    if (!quiet) {
      if (self.selection.length === self.getCount()) {
        self.elem.find(".foswikiAttachmentsSelectAll").hide();
      }
      self.showSelection();
    }
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
    $(".foswikiAttachments.foswikiFormSteps").livequery(function() {
      var $this = $(this);

      if (typeof($this.data("foswikiAttachments")) === 'undefined') {
        $this.data("foswikiAttachments", new FoswikiAttachments(this));
      }

      $(".foswikiMetaData").show(); // finally display it
 
    }); /** end of livequery for foswikiAttachments **/
  });
}(jQuery));
