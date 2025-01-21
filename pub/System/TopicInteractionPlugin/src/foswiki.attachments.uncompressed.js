/*

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

(c)opyright 2010-2024 Michael Daum http://michaeldaumconsulting.com

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

/* global foswiki, window */

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
    self.toggleOpts = $.extend({}, self.optionsButton.data());
    self.pager = self.elem.find(".foswikiAttachmentsPager");

    self.selection = [];
    if (typeof(self.opts.selection) !== 'undefined' && self.opts.selection !== "") {
      $.each(self.opts.selection.split(/\s*,\s*/), function(i, id) {
        if ($("#attachment_"+id).length) {
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
      self.selection.push("all");
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

    // edit behaviour
    self.elem.find(".foswikiAttachmentEditButton").on("click", function(ev) {
        ev.stopPropagation();
    });

    // add bulk action behaviour
    self.elem.find(".foswikiAttachmentsBulkAction select").on("change", function() {
      var $select = $(this),
          action = $select.val(),
          type = "", 
          len = self.selection?self.selection.length:0,
          opts = $select.parents(".foswikiAttachments:first").data();

      if (!len || !action) {
        return;
      }

      $select.val("");

      if (action === "createlink") {
        type = "file";
      } else if (action === "embed") {
        type = "";
      }

      if (action !== "move") {
        foswiki.loadTemplate({
          name: "metadata",
          expand: "attachments::confirmbulk::"+action,
          topic: opts.topic,
        }).done(function(data) {
            var $content = $(data.expand),
                $form = $content.find("form"),
                hiddenFlag = '';

            $("body").append($content);
            $form.find("input[type='hidden'][name='filename']").remove();
            $.each(self.selection, function(i, id) {
	      var attachmentOpts = $("#attachment_"+id).data();
              if (typeof(attachmentOpts) === 'undefined' ) {
                if (id === "all") {
                  $("<input type='hidden' name='filename' value='all' />").prependTo($form);
                }
              } else {
                $("<input type='hidden' name='filename' />").val(decodeURIComponent(attachmentOpts.filename)).prependTo($form);
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
              }
            });
            if (hiddenFlag === '?') {
              $content.find("input[name=hidefile]").parent().remove();
            } else if (hiddenFlag === 'h') {
              $content.find("input[name=hidefile]").prop("checked", true);
            } else if (hiddenFlag === 'v') {
              $content.find("input[name=hidefile]").prop("checked", false);
            }
            $content.find("input[name='action']").val(action);
            $content.find("input[name='type']").val(type);
            $form.attr("action", foswiki.getScriptUrl("rest", "TopicInteractionPlugin", action));
            $content.find(".someAttachments, .allAttachments").hide();
            if (len === 1 && self.selection[0] === 'all') {
              $content.find(".allAttachments").show();
            } else {
              $content.find(".someAttachments").show().find(".count").text(len);
            }
        });

      } else {
        // move attachments
        foswiki.loadTemplate({
          name: "metadata",
          expand: "attachments::moveattachment",
          topic: opts.topic
        }).done(function(data) {
            var $content = $(data.expand),
                $form = $content.find("form");

            $("body").append($content);

            $form.find("input[type='hidden'][name='filename']").remove();
            $.each(self.selection, function(i, id) {
	      var attachmentOpts = $("#attachment_"+id).data();
              if (typeof(attachmentOpts) === 'undefined') {
                if (id === "all") {
                  $("<input type='hidden' name='filename' value='all' />").prependTo($form);
                }
              } else {
                $("<input type='hidden' name='filename' />").val(decodeURIComponent(attachmentOpts.filename)).prependTo($form);
              }
            });

        });
      }
    });

    // add show more versions behaviour
    self.elem.find(".foswikiShowVersions").each(function() {
      var $this = $(this),
          $attachment = $this.parents(".foswikiAttachment:first"),
          attachmentOpts = $attachment.data(),
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
    $(".foswikiAttachmentEditorForm").livequery(function() {
      var $form = $(this);

      $form.ajaxForm({
        dataType:"json",
        beforeSerialize: function() {
          if (typeof(foswikiStrikeOne) !== 'undefined') {
            foswikiStrikeOne($form[0]);
          }
          $.pnotify_remove_all();
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
    $(".foswikiAttachmentConfirmDeleteForm").livequery(function() {
      var $form = $(this), filename;

      $form.ajaxForm({
        dataType:"json",
        beforeSerialize: function() {
          if (typeof(foswikiStrikeOne) !== 'undefined') {
            foswikiStrikeOne($form[0]);
          }
          $.pnotify_remove_all();
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
    $(".foswikiAttachmentMoveForm").livequery(function() {
      var $form = $(this),
        $dialog = $form.parents(".ui-dialog-content:first"),
        topicElem = $form.find(".foswikiTopicField"),
        webElem = $form.find(".foswikiWebField");

      self.log("found a new foswikiAttachmentMoveForm");
      $form.find("[name=restore]").on("change", function() {
          var $this = $(this),
              opts = $this.data(),
              webTopic = [opts.web, opts.topic];

          //console.log("opts=",opts);
          if ($this.is(":checked")) {
            webTopic = foswiki.normalizeWebTopicName(opts.movedFromWeb, opts.movedFromTopic);
          }
          //console.log("webTopic=",webTopic);

          webElem.select2("data", {
            id: webTopic[0],
            text: webTopic[0]
          });

          topicElem.select2("data", {
            id: webTopic.join("."),
            text: webTopic[1]
          });
      });

      $form.ajaxForm({
        dataType:"json",
        beforeSerialize: function() {
          if (typeof(foswikiStrikeOne) !== 'undefined') {
            foswikiStrikeOne($form[0]);
          }
          $.pnotify_remove_all();
        },
        beforeSubmit: function() {
          $dialog.dialog("close");
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
          $dialog.dialog("destroy");
        },
        error: function(xhr, msg) {
          var data;
          self.log("error");
          try {
            data = $.parseJSON(xhr.responseText);
            msg = data.error.message;
          } catch(err) {
            // ignore
            console.log(err);
          }
          $.unblockUI();
          $.pnotify({
             title: $.i18n("Move failed"),
             text: msg,
             type: 'error'
          });
          $dialog.dialog("destroy");
        }
      });
    });

    // ajaxify bulk action form
    $(".foswikiAttachmentConfirmBulkForm").livequery(function() {
      var $form = $(this), msgText, action;

      $form.ajaxForm({
        dataType:"json",
        beforeSerialize: function() {
          if (typeof(foswikiStrikeOne) !== 'undefined') {
            foswikiStrikeOne($form[0]);
          }
          $.pnotify_remove_all();
        },
        beforeSubmit: function() {
          msgText = $form.find(".foswikiAttachmentBulkMessage:visible .foswikiAttachmentBulkProgressMessage").html();
          action = $form.find("input[name='action']").val();
          $form.parent().dialog("close");
          $.blockUI({
            message:"<h1>"+msgText+"</h1>",
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

  /* display number of attachments ****************************************/
  FoswikiAttachments.prototype.displayAttachmentsCount = function() {
    var self = this,
        n = self.getCount();

    // set counter
    if (n) {
      self.elem.parents(".foswikiMetaData:first").find(".foswikiAttachmentsCount").text(n).show();
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
        if (id === "all") {
          self.elem.find(".foswikiAttachment").addClass("foswikiSelected");
        } else {
          $("#attachment_"+id).addClass("foswikiSelected");
        }
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
      if (self.selection[0] === 'all') {
        self.selection = [];
        self.elem.find(".foswikiAttachment").each(function() {
          var $attachment = $(this), 
              thisId = $attachment.data("id");
          if (thisId !== id) {
            self.selection.push(thisId);
          }
        });

      } else {
        for (var i = 0; i < self.selection.length; i++) {
          if (self.selection[i] === id) {
            self.selection.splice(i, 1);
            break;
          }
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
