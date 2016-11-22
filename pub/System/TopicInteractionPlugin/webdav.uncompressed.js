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
