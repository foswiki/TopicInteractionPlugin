# ---+ Extensions
# ---++ TopicInteractionPlugin
# ---+++ Runtime engines
# **STRING**
# This is the preference list of engines to test.
# Available engines: html5, flash, silverlight, gears, browserplus, html4
# Note that silverlight, gears and browserplus are disabled by default as these browser extensions are mostly unsupported and/or untested.
$Foswiki::cfg{TopicInteractionPlugin}{UploadEngines} = 'html5, flash, html4';

# ---+++ WebDAV 
# **REGEX**
# Specify a regular expression matching fileextensions to be webdav enabled in the attachments list of a topic. 
# By default this is undefined. Use 
# <code>qr/((xlt|xls|ppt|pps|pot|doc|dot)(x|m)?)|odc|odb|odf|odg|otg|odi|odp|otp|ods|ots|odt|odm|ott|oth|mpp/</code>
# as a good coverage of the most common office document extensions.
$Foswiki::cfg{TopicInteractionPlugin}{WebDAVFilter} = undef;

# *URL M**
# Defines the uri pattern for webdav links.
$Foswiki::cfg{TopicInteractionPlugin}{WebDAVUrl} = 'webdav://$host/dav/$web/$topic_files/$attachment';

1;
