# ---+ Extensions
# ---++ TopicInteractionPlugin
# ---+++ Runtime engines
# **STRING**
# This is the preference list of engines to test.
# Available engines: html5, flash, silverlight, gears, browserplus, html4
# Note that silverlight, gears and browserplus are disabled by default as these browser extensions are mostly unsupported and/or untested.
$Foswiki::cfg{TopicInteractionPlugin}{UploadEngines} = 'html5, flash, html4';

# ---+++ WebDAV filter
# **REGEX EXPERT**
# Specify a regular expression matching fileextensions to be webdav enabled in the attachments list of a topic. 
# This configuration setting will only take effect when the WebDAVLinkPlugin is enabled too.
$Foswiki::cfg{TopicInteractionPlugin}{WebDAVFilter} = qr/((xlt|xls|ppt|pps|pot|doc|dot)(x|m)?)|odc|odb|odf|odg|otg|odi|odp|otp|ods|ots|odt|odm|ott|oth|mpp/;

1;
