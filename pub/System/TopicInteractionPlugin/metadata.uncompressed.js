/*

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

(c)opyright 2010-2016 Michael Daum http://michaeldaumconsulting.com

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

/*global ActiveXObject:false */
"use strict";
jQuery(function($) {

  /* init attachments tab *************************************************/
  $(".foswikiAttachments.foswikiFormSteps:not(.foswikiInitedAttachments)").livequery(function() {
    var $this = $(this),
        opts = $.extend({}, $this.metadata(), $this.data()),
        url = foswiki.getScriptUrl("rest", "RenderPlugin", "template", {
          "name": "metadata",
          "render": "on",
          "topic": opts.topic
        }),
        $container = $this.parent(),
        $optionsButton = $this.find(".foswikiAttachmentsOptionsToggle"),
        $addButton = $this.find(".foswikiAttachmentsUploadToggle"),
        $optionsLabel = $optionsButton.find("span:last"),
        $toggleContainer = $this.find(".foswikiAttachmentsOptionsToggleContainer"),
        $uploadContainer = $this.find(".foswikiAttachmentsUploadToggleContainer"),
        toggleOpts = $.extend({}, $optionsButton.metadata(), $optionsButton.data()),
        $pager = $this.find(".foswikiAttachmentsPager");

    $this.addClass(".foswikiInitedAttachments");

    if (!$optionsLabel.length) {
      $optionsLabel = $optionsButton;
    }

    if (typeof(opts.selection) === 'undefined' || opts.selection == "") {
      opts.selection = [];
    } else {
      opts.selection = opts.selection.split(/\s*,\s*/);
    }
    
    // set counter
    if ($pager.length) {
      opts.nrAttachments = $this.find(".foswikiAttachmentsPager").metadata().count;
      $this.parents(".foswikiMetaData:first").find(".foswikiAttachmentsCount").text("("+opts.nrAttachments+")");
    } else {
      opts.nrAttachments = 0;
      $this.parents(".foswikiMetaData:first").find(".foswikiAttachmentsCount").text("");
    }

    /* function to reload all attachments **********************************/
    function loadAttachments() {
      var thisUrl = url, i;

      thisUrl += ";expand=attachments";
      if (typeof(opts.hidden) !== 'undefined') {
        thisUrl += ";attachments_hidden=" + opts.hidden;
      }
      if (typeof(opts.sort) !== 'undefined') {
        thisUrl += ";attachments_sort=" + opts.sort;
      }
      if (typeof(opts.reverse) !== 'undefined') {
        thisUrl += ";attachments_reverse=" + opts.reverse;
      }
      if (typeof(opts.filter) !== 'undefined' && opts.filter != '') {
        thisUrl += ";attachments_filter="+encodeURI(opts.filter);
      }
      if (typeof(opts.selection) !== 'undefined') {
        for (i = 0; i < opts.selection.length; i++) {
          thisUrl += ";attachments_selection="+encodeURI(opts.selection[i].replace(/\\\./, '.'));
        }
      }
      if (typeof(opts.limit) !== 'undefined') {
        thisUrl += ";attachments_limit=" + opts.limit;
      }
      if (typeof(opts.skip) !== 'undefined') {
        thisUrl += ";attachments_skip=" + opts.skip;
      }
      if (typeof(opts.showOptions) !== 'undefined') {
        thisUrl += ";attachments_showoptions=" + opts.showOptions;
      }
      if (typeof(opts.showUploader) !== 'undefined') {
        thisUrl += ";attachments_showuploader=" + opts.showUploader;
      }
      if (typeof(opts.cols) !== 'undefined') {
        thisUrl += ";attachments_cols=" + opts.cols;
      }
      $this.block({
        message:null,
        fadeIn: 0,
        fadeOut: 0,
        overlayCSS: {
          cursor:'progress'
        }
      });
      $container.load(thisUrl, function() {
        $this.unblock();
        $container.height('auto');
      });
    }

    /* switch number of columns based on screen width **********************/
    function dynCols() {
      var thisWidth = $this.width(), 
          newClass, maxHeight, height, 
          $attachments = $this.find(".foswikiAttachment");

      if (thisWidth > 1300 && opts.nrAttachments >= 3) {
        newClass = "foswikiAttachmentsCols3";
        opts.cols = 3;
      } else if (thisWidth > 940 && opts.nrAttachments >=2) {
        newClass = "foswikiAttachmentsCols2";
        opts.cols = 2;
      } else {
        //$.log("METADATA: thisWidth="+thisWidth+" ... removing cols");
        newClass = "foswikiAttachmentsCols1";
        opts.cols = 1;
      }

      if (newClass && !$this.hasClass(newClass)) {
        $this.removeClass("foswikiAttachmentsCols1 foswikiAttachmentsCols2 foswikiAttachmentsCols3");
        $this.addClass(newClass);
        //$.log("METADATA: thisWidth="+thisWidth+" ... switching class="+newClass);
      } else {
        //$.log("METADATA: thisWidth="+thisWidth+" ... no change");
      }

      // adjust bucket height to clean up differences causing probs when floating
      if (opts.cols > 1) {
        maxHeight = 0;
        $attachments.css('height', 'auto').each(function() {
          height = $(this).height();
          if (height > maxHeight) {
            maxHeight = height;
          }
        });
        $attachments.height(maxHeight);
      } else {
        $attachments.height('auto');
      }

      window.setTimeout(function() {
          $(window).one("resize.attachments", dynCols);
      }, 300);
    }

    /* mark current selection **********************************************/
    function showSelection() {
      var i, id;

      $this.find(".foswikiAttachmentSelected").removeClass("foswikiAttachmentSelected");
      if (opts.selection) {
        for (i = 0; i < opts.selection.length; i++) {
          id = encodeURIComponent(opts.selection[i]);
          // jQuery can't handle id's with umlauts in it
          $(document.getElementById(id)).addClass("foswikiAttachmentSelected");
        }
        if (opts.selection.length) {
          $this.find(".foswikiAttachmentsBulkAction, .foswikiAttachmentsClearAll").show();
          $this.find(".foswikiAttachmentsSelected").text(opts.selection.length);
        } else {
          $this.find(".foswikiAttachmentsBulkAction, .foswikiAttachmentsClearAll").hide();
        }
      } else {
        $this.find(".foswikiAttachmentsBulkAction, .foswikiAttachmentsClearAll").hide();
      }
    }

    /* add an id to the selection ******************************************/
    function select(id) {
      if (!id) {
        return;
      }
      //$.log("METADATA: select("+id+")");
      if (typeof(opts.selection) === 'undefined') {
        opts.selection = [];
      }
      opts.selection.push(id);
      if (opts.selection.length == opts.nrAttachments) {
        $this.find(".foswikiAttachmentsSelectAll").hide();
      }
      showSelection();
    }

    /* remove an id from the selection *************************************/
    function clear(id) {
      if (opts.selection) {
        for (var i = 0; i < opts.selection.length; i++) {
          if (opts.selection[i] == id) {
            opts.selection.splice(i, 1);
            break;
          }
        }
      }
      $this.find(".foswikiAttachmentsSelectAll").show();
      showSelection();
    }

    /* empty the selection *************************************************/
    function clearSelection()  {
      opts.selection = [];
      showSelection();
    }

    /* *********************************************************************/
    function hideOptionsContainer() {
      $optionsLabel.html(toggleOpts.showText);
      $toggleContainer.slideUp({easing:'easeInOutQuad', duration:'fast'});
      opts.showOptions = 'off';
    }

    /* *********************************************************************/
    function showOptionsContainer() {
      $optionsLabel.html(toggleOpts.hideText);
      $toggleContainer.slideDown({easing:'easeInOutQuad', duration:'fast'});
      opts.showOptions = 'on';
    }

    /* *********************************************************************/
    function hideUploader() {
      $uploadContainer.slideUp({easing:'easeInOutQuad', duration:'fast'});
      opts.showUploader = 'off';
    }

    /* *********************************************************************/
    function showUploader() {
      $uploadContainer.slideDown({easing:'easeInOutQuad', duration:'fast'});
      opts.showUploader = 'on';
      //$.log("METADATA: triggering refresh");
      $uploadContainer.find(".jqUploader").trigger("Refresh");
    }

    /* *********************************************************************/
    function loadDialog(params) {
      var $this, data;

      if (typeof(params.id) !== 'undefined') {
        $this = $(params.id);
        if ($this.length) {
          $this.find("form").resetForm();
          if (typeof(params.callback) === 'function') {
            params.callback.call($this);
          }
          return;
        }
      }

      data = $.extend({}, params.data, {
        name: 'metadata',
        expand: params.template,
        topic: foswiki.getPreference("WEB")+"."+foswiki.getPreference("TOPIC")
      });

      $.ajax({
        url: foswiki.getScriptUrl("rest", "RenderPlugin", "template"),
        data: data,
        dataType: 'html',
        success: function(data) {
          var $this = $(data);
          $this.on("dialogopen", function(ev, ui) {
            if (typeof(params.callback) === 'function') {
              params.callback.call($this);
            }
          });
          $this.appendTo("body");
        }
      });
    }

    // dynamic layout
    dynCols();

    // mark current selection
    showSelection();

    // add toggle behaviour
    $optionsButton.click(function() {
      if ($toggleContainer.is(":visible")) {
        hideOptionsContainer();
      } else {
        showOptionsContainer();
        hideUploader();
      }
      return false;
    });

    $addButton.click(function() {
      if ($uploadContainer.is(":visible")) {
        hideUploader();
      } else {
        showUploader();
      }
      hideOptionsContainer();
      return false;
    });

    // refresh uploader if visible initially
    if ($uploadContainer.is(":visible")) {
      window.setTimeout(function() {
        //$.log("METADATA: triggering refresh in timer");
        $uploadContainer.find(".jqUploader").trigger("Refresh");
      }, 100);
    }

    // add display hidden behaviour
    $this.find(".foswikiDisplayHidden input").change(function() {
      opts.hidden = $(this).attr('checked')?'on':'off';
      loadAttachments();
      return false;
    });

    // add behaviour to filter
    $this.find(".foswikiFilter input").bind("keypress", function(event) {
      var $input = $(this), val;

      if(event.keyCode == 13) {
        val = $input.val();
        if (val === 'none') {
          val = '';
        } 
        opts.filter = val;
        loadAttachments();
        event.preventDefault();
        return false;
      }
    });

    // add sort behaviour
    $this.find(".foswikiSortBy select").change(function() {
      var $this = $(this);
      opts.sort = $this.val();
      if (opts.sort == "date") {
        opts.reverse = 'on';
      } else {
        opts.reverse = 'off';
      }
      opts.skip = 0;
      //$.log("METADATA: sort="+opts.sort+" reverse="+opts.reverse);
      loadAttachments();
      return false;
    });

    // add limit behaviour
    $this.find(".foswikiResultsPerPage select").change(function() {
      var $this = $(this);
      opts.limit = $this.val();
      opts.skip = 0;
      //$.log("METADATA: limit="+opts.limit);
      loadAttachments();
      return false;
    });

    // add pager behaviour
    $this.find(".foswikiAttachmentsPager a").click(function() {
      var $this = $(this);
      opts = $.extend(opts, $this.metadata(), $this.data());
      loadAttachments();
      return false;
    });

    // add attachment behaviour
    $this.find(".foswikiAttachment").hover(
      function() {
        $(this).addClass("foswikiAttachmentHover");
      },
      function() {
        $(this).removeClass("foswikiAttachmentHover");
      }
    ).click(function(e) {
      var $attachment = $(this), id = decodeURIComponent($attachment.attr('id'));

      if (!$(e.target).is("a,img")) { // dont propagate the attachment clicks
        $attachment.toggleClass("foswikiAttachmentSelected");

        if ($attachment.hasClass("foswikiAttachmentSelected")) {
          select(id);
        } else {
          clear(id);
        }
        e.stopPropagation();
        return false;
      }
    });

    // add listener for Refresh event
    $this.bind("Refresh", function(e, files) {
      //$.log("METADATA: got Refresh event");
      if (files) {
        //$.log("refreshing from files");
        clearSelection();
        $.each(files, function(i, file) {
          select(file.name);
        });
      }
      loadAttachments();
      return false;
    });
    
    // add select all behaviour
    $this.find(".foswikiAttachmentsSelectAll").click(function() {
      //$.log("METADATA: clicked select all");
      opts.selection = [];
      $this.find("input.foswikiAttachmentsAll").each(function() {
        opts.selection.push($(this).val());
      });
      $(this).hide();
      showSelection();
      return false;
    });

    // add clear all behaviour
    $this.find(".foswikiAttachmentsClearAll").click(function() {
      clearSelection();
      $this.find(".foswikiAttachmentsSelectAll").show();
      return false;
    });

    // add preview behaviour
    $this.find(".foswikiAttachmentPreviewButton").click(function() {
      var $button = $(this),
          $attachment = $button.parents(".foswikiAttachment:first"),
          attachmentOpts = $.extend({}, $attachment.metadata(), $attachment.data()),
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

      loadDialog({
        template: "attachments::previewer::"+previewType, 
        data: {
          filename: decodeURIComponent(attachmentOpts.filename)
        }, 
        callback: function() {
          var $this = this;
          $.unblockUI();
          $this.parent().find(".ui-dialog-title").text(decodeURIComponent(attachmentOpts.filename));
        }
      });

      return false;
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
        success: function(data, statusText, xhr) {
          $.unblockUI();
          loadAttachments();
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

    // edit behaviour
    $this.find(".foswikiAttachmentEditButton").click(function(ev) {
        ev.stopPropagation();
    });
  
    // add button behaviour 
    $this.find(".foswikiAttachmentPropertiesButton").click(function() {
      var $button = $(this),
          $attachment = $button.parents(".foswikiAttachment:first"),
          attachmentOpts = $.extend({}, $attachment.metadata(), $attachment.data()),
          thumbnail = $attachment.find(".foswikiThumbnail").clone().removeClass("foswikiLeft");

      //$.log("METADATA: clicked edit attachment");

      loadDialog({
        id:"#foswikiAttachmentEditor", 
        template:"attachments::editor", 
        callback: function() {
          var $this = this;

          var $hideFile = $this.find("input[name=hidefile]"),
              $isThumbnail = $this.find("input[name=isthumbnail]");

          //$.log("METADATA: show attachment editor");
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
            $hideFile.attr("checked", "checked");
          } else {
            $hideFile.removeAttr("checked");
          }
          if (attachmentOpts.fileattr.match(/t/)) {
            $isThumbnail.attr("checked", "checked");
          } else {
            $isThumbnail.removeAttr("checked");
          }
          $this.dialog("option", "position", "center");
        }
      });

      return false;
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
        success: function(data, statusText, xhr) {
          $.unblockUI();
          clear(filename);
          loadAttachments();
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


    // add delete button behaviour
    $this.find(".foswikiAttachmentDeleteButton").click(function() {
      var $button = $(this),
          $attachment = $button.parents(".foswikiAttachment:first"),
          attachmentOpts = $.extend({}, $attachment.metadata(), $attachment.data()),
          thumbnail = $attachment.find(".foswikiThumbnail").clone().removeClass("foswikiLeft");

      loadDialog({
        id:"#foswikiAttachmentConfirmDelete", 
        template:"attachments::confirmdelete",
        callback: function() {
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
        success: function(data, statusText, xhr) {
          $.unblockUI();
          clearSelection();
          loadAttachments();
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

    // add move button behaviour
    $this.find(".foswikiAttachmentMoveButton").click(function() {
      var $button = $(this),
          $attachment = $button.parents(".foswikiAttachment:first"),
          attachmentOpts = $.extend({}, $attachment.metadata(), $attachment.data()),
          thumbnail = $attachment.find(".foswikiThumbnail").clone().removeClass("foswikiLeft");

      loadDialog({
        id: "#foswikiAttachmentMove", 
        template: "attachments::moveattachment",
        callback: function() {
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
        success: function(data, statusText, xhr) {
          $.unblockUI();
          // perform reload
          if (action == "createlink" || action == "createimagegallery") {
            //$.log("METADATA: reloading topic");
            window.location.href = foswiki.getScriptUrl("view", foswiki.getPreference("WEB"), foswiki.getPreference("TOPIC"));
          } 
          
          // perform redirect
          else if (action == "download") {
            //$.log("METADATA: redirect url="+data.result);
            window.location.href = data.result;
          } 

          // clear selection
          else if (action == 'delete') {
            clearSelection();
            loadAttachments();
          }
          
          // default
          else {
            loadAttachments();
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
    
    // add bulk action behaviour
    $this.find(".foswikiAttachmentsBulkAction select").change(function() {
      var $select = $(this),
          action = $select.val(), 
          msgClass,
          len = opts.selection?opts.selection.length:0;

      if (!len || !action) {
        return;
      }

      $select.val("");

      if (action == "createlink") {
        msgClass = ".foswikiAttachmentBulkCreateLinks";
      } else if (action == "createimagegallery") {
        msgClass = ".foswikiAttachmentBulkCreateImageGallery";
      } else if (action == "download") {
        msgClass = ".foswikiAttachmentBulkDownload";
      } else if (action == "hide") {
        msgClass = ".foswikiAttachmentBulkHide";
      } else if (action == "unhide") {
        msgClass = ".foswikiAttachmentBulkUnHide";
      } else if (action == "delete") {
        msgClass = ".foswikiAttachmentBulkDelete";
      } else if (action == "move") {
        /* use the moveattachment dialog */
      } else {
        alert("unknown action "+action);
        return;
      }

      if (action != "move") {
        loadDialog({
          id: "#foswikiAttachmentConfirmBulk", 
          template: "attachments::confirmbulkaction",
          callback: function() {
            var $this = this,
                $form = $this.find("form");

            $form.find("input[type='hidden'][name='filename']").remove();
            $.each(opts.selection, function(i, val) {
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
        loadDialog({
          id: "#foswikiAttachmentMove", 
          template: "attachments::moveattachment",
          callback: function() {
            var $this = this,
                $form = $this.find("form");

            $form.find("input[type='hidden'][name='filename']").remove();
            $.each(opts.selection, function(i, val) {
              $("<input type='hidden' name='filename' />").val(val).prependTo($form);
            });
            $this.find(".foswikiAttachmentsCount").text(opts.selection.length);
            $this.find(".foswikiThumbnailContainer").empty();
            $this.find(".foswikiGenericThumbnail").show();

            $this.dialog("option", "position", "center");
          }
        });
      }
    });

    // add show more versions behaviour 
    $this.find(".foswikiShowVersions").each(function() {
      var $this = $(this),
          $attachment = $this.parents(".foswikiAttachment:first"),
          attachmentOpts = $.extend({}, $attachment.metadata(), $attachment.data()),
          $versionContainer = $attachment.find(".foswikiVersionsContainer"),
          thisUrl = url + ";expand=attachments::versions" + ";filename="+attachmentOpts.filename;
      
      $this.click(function() {
        if($versionContainer.is(".foswikiVersionsContainerLoaded")) {
          $this.hide();
          $attachment.find(".foswikiHideVersions").show();
          $versionContainer.slideDown("fast", dynCols);
        } else {
          $versionContainer.show();
          $versionContainer.load(thisUrl, function() {
            $versionContainer.addClass("foswikiVersionsContainerLoaded");
            $attachment.effect("highlight");
            $this.hide();
            $attachment.find(".foswikiHideVersions").show();
            dynCols();
          });
        }
        return false;
      });
    });
   
    // add hide more versions behaviour 
    $this.find(".foswikiHideVersions").each(function() {
      var $this = $(this),
          $attachment = $this.parents(".foswikiAttachment:first"),
          $versionContainer = $attachment.find(".foswikiVersionsContainer");
      
      $this.click(function() {
        $this.hide();
        $attachment.find(".foswikiShowVersions").show();
        $versionContainer.slideUp("fast", dynCols);
        return false;
      });
    });

  }); /** end of livequery for foswikiAttachments **/

  // detectos
  if (typeof($.detectOS) === 'undefined') {
    $.detectOS = {
      Windows: (-1 != navigator.platform.indexOf("Win")),
      MacOS: (-1 != navigator.platform.indexOf("Mac")),
      Linux: (-1 != navigator.platform.indexOf("Linux")),
      Unix: (-1 != navigator.platform.indexOf("X11")),
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

  // add webdav behavior
  $(".jqWebDAVLink").livequery(function() {
    var $this = $(this);

    if ($.detectOS.Windows || $.detectOS.MacOS) {
      $this.on("click", function() {
        var $this = $(this), 
            url = $this.attr("href"),
            schema,
            officeSuite = foswiki.getPreference("TopicInteractionPlugin").officeSuite || 'msoffice';

        if (officeSuite === 'msoffice') {
          schema = getMsOfficeSchema(url) + ':ofe|u|';
          url = schema + url.replace(/^.*:/, window.location.protocol);
        } else if (officeSuite === 'libreoffice') {
          schema = 'vnd.sun.star.webdav:';
          url = url.replace(/^.*:/, schema);
        }

        $("<iframe />").attr("src", url).appendTo("body");

        return false;
      });
    } 
  });
});
