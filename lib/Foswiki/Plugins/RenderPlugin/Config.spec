# ---+ Extensions
# ---++ RenderPlugin
# This is the configuration used by the <b>RenderPlugin</b>.

# **BOOLEAN EXPERT LABEL="Cache Control" CHECK="undefok emptyok"**
# cache control for all rest handlers. seconds for the browser to cache the response. set to 0 to disable client side caching.
# the default is 8 hours in seconds.
$Foswiki::cfg{RenderPlugin}{CacheControl} = 28800;

# **STRING LABEL="Macros allowed for the tag handler" CHECK="undefok emptyok"**
# list of allowed macros to be expanded by the "tag" REST handler. note that additional macros can be registered automatically by other plugins.
$Foswiki::cfg{RenderPlugin}{TagHandler}{AllowedMacros} = "";

# **BOOLEAN LABEL="Enable expand handler" CHECK="undefok emptyok"**
# enable/disable deprecated "expand" REST handler
$Foswiki::cfg{RenderPlugin}{ExpandHandler}{Enabled} = 0;

# **BOOLEAN LABEL="Enable render handler" CHECK="undefok emptyok"**
# enable/disable deprecated "render" REST handler
$Foswiki::cfg{RenderPlugin}{RenderHandler}{Enabled} = 0;

1;

