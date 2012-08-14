var LEELA;

if (LEELA === undefined) {
    LEELA = {};
}

LEELA.widget = function (root, opts) {
    var options = opts || {};

    var cspline_i = function (x, xk_1, yk_1, xk, yk, xk1, yk1, xk2, yk2) {
      var t   = (x-xk) / (xk1 - xk);
      var t2  = t*t;
      var t3  = t2*t;
      var h00 = 2*t3 - 3*t2 + 1;
      var h10 = t3 - 2*t2 + t;
      var h01 = -2*t3 + 3*t2;
      var h11 = t3 - t2;
      var m0  = (yk1-yk)/(2*(xk1 - xk)) + (yk-yk_1)/(2*(xk-xk_1));
      var m1  = (yk2-yk1)/(2*(xk2 - xk1)) + (yk1-yk)/(2*(xk1-xk));
      return([x, h00*yk + h10*(xk1-xk)*m0 + h01*yk1 + h11*(xk1-xk)*m1]);
    };

    var cspline = function (data) {
      var ndata = [];
      var len   = data.length;
      var res   = 25;

      for (var k=0; k<len-1; k+=1) {
        var x    = data[k][0];
        var xk_1 = (data[k-1] || [0])[0];
        var yk_1 = (data[k-1] || [0,0])[1];
        var xk   = data[k][0];
        var yk   = data[k][1];
        var xk1  = data[k+1][0];
        var yk1  = data[k+1][1];
        var xk2  = (data[k+2] || [0])[0];
        var yk2  = (data[k+2] || [0,0])[1];
        var s    = (xk1 - xk)/res;
        for (var u=1; u<res; u+=1) {
          x += s;
          ndata.push(cspline_i(x, xk_1, yk_1, xk, yk, xk1, yk1, xk2, yk2));
        }
      }

      return(ndata);
    };

    var format = function (json) {
      var series = [];
      for (var k in json) {
        if (k!=="source" && json.hasOwnProperty(k)) {
          series.push({ label: k,
                        data: cspline(json[k])
                      });
        }
      }
      return(series);
    };

    var install = function (json) {
        var series    = format(json);
        var container = document.getElementById(root);
        var myopts    = { xaxis: { mode: "time",
                                   timeUnit: "second",
                                   timeFormat: "%d %b %H:%M",
                                   minorTickFreq: 18,
                                   noTicks: 10
                                 },
                          yaxis: { min: 0
                                 },
                          title: options.title || (json.source.hostname + " - " + json.source.service),
                          subtitle: options.subtitle || "Powered by locaweb",
                          selection: { mode: "x"
                                     },
                          legend: { position: "ne"
                                  },
                        };
        var resetZoom = function () {
            delete myopts.xaxis.min; delete myopts.xaxis.max;
        };

        Flotr.draw(container, series, myopts);

        Flotr.EventAdapter.observe(container, 'flotr:select', function (area) {
          myopts.xaxis.min = area.x1; myopts.xaxis.max = area.x2;
          Flotr.draw(container, series, myopts);
        });

        Flotr.EventAdapter.observe(container, 'flotr:click', function () { resetZoom(); Flotr.draw(container, series, myopts); });
    };

    return({"install": install});
}