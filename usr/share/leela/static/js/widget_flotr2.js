var LEELA;

if (LEELA === undefined) {
    LEELA = {};
}

LEELA.widget = function (root, opts) {
    var options = opts || {};

    var format = function (json) {
      var series = [];
      for (var k in json) {
        if (k!=="source" && json.hasOwnProperty(k)) {
          series.push({ label: k,
                        data: json[k]
                      });
        }
      }
      return(series);
    };

    var install = function (json) {
        var series    = format(json);
        var container = document.getElementById(root);
        var resetZoom = function () {
            delete options.xaxis.min; delete options.xaxis.max;
            delete options.yaxis.min; delete options.yaxis.max;
        };

        options.selection = { mode : 'x', fps : 30 };
        options.title = options.title || (json.source.hostname + " - " + json.source.service);
        options.subtitle = options.subtitle || "Powered by locaweb";

        options.xaxis             = options.xaxis || {};
        options.xaxis.mode        = "time";
        options.xaxis.labelsAngle = 45;
        options.xaxis.timeFormat  = "%H:%M";
        options.xaxis.timeUnit    = "second";

        Flotr.draw(container, series, options);

        Flotr.EventAdapter.observe(container, 'flotr:select', function (area) {
            options.xaxis.min = area.x1; options.xaxis.max = area.x2;
            options.yaxis.min = area.y1; options.yaxis.max = area.y2;
            Flotr.draw(container, series, options);
        });

        Flotr.EventAdapter.observe(container, 'flotr:click', function () { resetZoom(); Flotr.draw(container, series, options); });
    };

    return({"install": install});
}
