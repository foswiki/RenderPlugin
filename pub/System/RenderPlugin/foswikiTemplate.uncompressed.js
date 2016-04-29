/*
 * foswiki template loader 1.1
 *
 * (c)opyright 2015 Michael Daum http://michaeldaumconsulting.com
 *
 * Dual licensed under the MIT and GPL licenses:
 *   http://www.opensource.org/licenses/mit-license.php
 *   http://www.gnu.org/licenses/gpl.html
 *
 */
(function($) {

  /***************************************************************************
   * globals
   */
  var defaultParams = {
    "render": "on",
    "zones": "script, head"
  };

  /***************************************************************************
   * class definition
   */
  function Plugin(opts) {
    var self = this;

    self.successFunc = opts.success || function() {},
    self.errorFunc = opts.error || function() {},
    self.url = opts.url || foswiki.getScriptUrl("rest", "RenderPlugin", "jsonTemplate");

    delete opts.success;
    delete opts.error;
    delete opts.url;

    self.opts = $.extend({}, defaultParams, opts);
  };

  /***************************************************************************
   * logging
   */
  Plugin.prototype.log = function() {
    var self = this,
      args = $.makeArray(arguments);

    args.unshift("JST: ");
    $.log.apply(self, args);
  };

  /***************************************************************************
   * loadTemplate
   */
  Plugin.prototype.loadTemplate = function() {
    var self = this;

    $.ajax({
      url: self.url,
      data: self.opts,
      dataType: "json",
      success: function(data, status, xhr) {
        self.processZones(data.zones);
        self.successFunc(data.expand, status, xhr);
      },
      error: function(xhr, status, error) {
        self.errorFunc(xhr, status, error);
      } 
    });
  };

  /***************************************************************************
   * processZone
   */
  Plugin.prototype.processZones = function(zones) {
    var self = this;

    $.each(zones, function(zoneName) {
        var zone = zones[zoneName],
            zonePos = $("."+zoneName).last();

      $.each(zone, function(i) {
        var item = zone[i],
            selector = "."+zoneName+"."+item.id.replace(/([^a-zA-Z0-9_\-])/g, '\\$1');

        if (!item.id.match(/^(JQUERYPLUGIN::FOSWIKI::PREFERENCES)?$/)) {
          if ($(selector).length > 0) {
            self.log("zone=",zoneName,"item ",item.id+" already loaded");
          } else {
            self.log("... loading ",item.id,"to zone",zoneName);
            
            // load async'ly 
            window.setTimeout(function() {
              zonePos.after(item.text);
            });
          }
        }
      });
    });
  };

  /***************************************************************************
   * make globally available
   */
  foswiki.loadTemplate = function(opts) {
    var plugin = new Plugin(opts);
    return plugin.loadTemplate();
  };
    
})(jQuery);
