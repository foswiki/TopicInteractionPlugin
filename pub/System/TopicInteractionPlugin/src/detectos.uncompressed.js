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
