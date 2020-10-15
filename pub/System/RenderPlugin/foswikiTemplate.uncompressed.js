/*
 * foswiki template loader 2.21
 *
 * (c)opyright 2015-2020 Michael Daum http://michaeldaumconsulting.com
 *
 * Licensed under the GPL license http://www.gnu.org/licenses/gpl.html
 *
 */
(function($) {

  /***************************************************************************
   * globals
   */
  var defaultParams = {
    "debug": false,
    "expand": "on",
    "render": "on",
    "zones": "script, head",
    "async": false,
    "cachecontrol": 0,
    "success": function() {},
    "error": function(response) {
      console && console.error(response);
    },
  };

  /***************************************************************************
   * class definition
   */
  function FoswikiTemplate(opts) {
    var self = this;

    self.opts = $.extend({
      "topic": foswiki.getPreference("WEB")+"."+foswiki.getPreference("TOPIC")
    }, defaultParams, opts);

    self.successFunc = self.opts.success;
    self.errorFunc = self.opts.error;
    self.url = self.opts.url || foswiki.getScriptUrl("rest", "RenderPlugin", "jsonTemplate");

    delete self.opts.success;
    delete self.opts.error;
    delete self.opts.url;

    self.log("opts=",opts);
  };

  /***************************************************************************
   * logging
   */
  FoswikiTemplate.prototype.log = function() {
    var self = this, args;

    if (console && self.opts.debug) {
      args = $.makeArray(arguments);

      args.unshift("FoswikiTemplate: ");
      console.log.apply(self, args);
    }
  };

  /***************************************************************************
   * loadTemplate
   */
  FoswikiTemplate.prototype.loadTemplate = function() {
    var self = this;

    return $.ajax({
      url: self.url,
      async: true,
      data: self.opts,
      dataType: "json",
      success: function(data, status, xhr) {
        self.log("data=",data);
        self.processZones(data.zones);
        self.successFunc(data.expand, status, xhr);
      },
      error: function(xhr, status, error) {
        var response = xhr.responseText.replace(/^ERROR: .*\- /, "").replace(/ at .*/, "");
        self.errorFunc(response);
      } 
    });
  };

  /***************************************************************************
   * processZone
   */
  FoswikiTemplate.prototype.processZones = function(zones) {
    var self = this;

    $.each(zones, function(zoneName) {
        var zone = zones[zoneName],
            zonePos = $("."+zoneName).last(), text;

      $.each(zone, function(i) {
        var item = zone[i],
            selector = "."+zoneName+"."+item.id.replace(/([^a-zA-Z0-9_\-])/g, '\\$1');

        if (!item.id.match(/^(JQUERYPLUGIN::FOSWIKI::PREFERENCES)?$/)) {
          if ($(selector).length > 0) {
            //self.log("zone=",zoneName,"item ",item.id+" already loaded");
          } else {
            text = item.text;
            if (self.opts.async) {
              text = item.text.replace(/<script /g, "<script async ");
            } else {
              text = item.text;
            }
            self.log("... loading ",item.id,"to zone",zoneName);
            self.log("text=",text);
            zonePos.after(text);
          }
        }
      });
    });
  };

  /***************************************************************************
   * export
   */
  foswiki.loadTemplate = function(opts) {
    var ft = new FoswikiTemplate(opts);
    return ft.loadTemplate();
  };

  /***************************************************************************
   * foswikiDialogLink
   */
  $(document).on("click", ".foswikiDialogLink", function() {
    var $this = $(this), 
        href = $this.attr("href") || '',
        opts = $.extend({
          name: href.replace(/^#/, ""),
          expand: "dialog"
        }, $this.data());

    foswiki.loadTemplate(opts).done(function(data) {
      var $content = $(data.expand);

      $content.hide();
      $("body").append($content);
      $content.data("autoOpen", true).on("dialogopen", function() {
        $this.trigger("opened");
       });
    });

    return false;
  });
    
})(jQuery);
