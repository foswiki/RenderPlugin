/*
 * foswiki template loader 3.00
 *
 * (c)opyright 2015-2022 Michael Daum http://michaeldaumconsulting.com
 *
 * Licensed under the GPL license http://www.gnu.org/licenses/gpl.html
 *
 */
"use strict";
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

    //self.log("opts=",opts);
  }

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
        //self.log("data=",data);
        self.processZones(data.zones);
        self.successFunc(data.expand, status, xhr);
      },
      error: function(xhr) {
        var response = xhr.responseText.replace(/^ERROR: .*- /, "").replace(/ at .*/, "");
        self.errorFunc(response);
      } 
    });
  };

  /***************************************************************************
   * processZone
   */
  FoswikiTemplate.prototype.processZones = function(zones) {
    var self = this;

    Object.keys(zones).forEach(function(zoneName) {
      var zone = {}, seen = {}, sortedItems = [];

      self.log("processing zone ",zoneName);
        
      // hash the zone items
      zones[zoneName].forEach(function(item) {
        var selector = $("."+zoneName+"."+item.id.replace(/([^a-zA-Z0-9_-])/g, '\\$1'));
        if (item.id !== 'JQUERYPLUGIN::FOSWIKI::PREFERENCES' && selector.length === 0) {
          zone[item.id] = item;
        }
      });

      // collect all items
      Object.keys(zone).forEach(function(id) {
        _visitZoneItem(zone[id], zone, seen, sortedItems);
      });

      //self.log("sortedItems=",sortedItems);

      // process all items
      sortedItems.forEach(function(item) {
        var text = item.text;

        if (self.opts.async) {
          text = item.text.replace(/<script /g, "<script async ");
        } else {
          text = item.text;
        }

        self.log("... loading ",item.id);
        //self.log("... text=",text);

        $("."+zoneName).last().after(text);
      });
    });
  };

  function _visitZoneItem(item, zone, seen, result) {

    if (typeof(item) === 'undefined' || seen[item.id]) {
      return;
    }
    seen[item.id] = 1;

    item.requires.forEach(function( id) {
      _visitZoneItem(zone[id], zone, seen, result);
    });

    //console.log("adding item",item.id);
    result.push(item);
  }

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
