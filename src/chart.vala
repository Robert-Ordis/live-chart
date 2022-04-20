using Cairo;

namespace LiveChart {

    public errordomain ChartError
    {
        EXPORT_ERROR,
        SERIE_NOT_FOUND
    }

    public class Chart : Gtk.DrawingArea {

        public Grid grid { get; set; default = new Grid(); }
        public Background background { get; set; default = new Background(); } 
        public Legend legend { get; set; default = new HorizontalLegend(); } 
        public Config config;
        public Series series;

        private uint source_timeout = 0;
        private double play_ratio = 1.0;
        
        private int64 prev_time;
        
        private PointReticle pointing = new PointReticle();
        
        public Chart(Config config = new Config()) {
            this.config = config;

#if GTK3
            this.size_allocate.connect((allocation) => {
                this.config.height = allocation.height;
                this.config.width = allocation.width;
            });
            this.draw.connect(render);
#endif            
#if GTK4
            this.set_draw_func((_, ctx, width, height) => {
                this.config.height = height;
                this.config.width = width;
                this.render(_, ctx);
            });
#endif

            this.refresh_every(100);

            series = new Series(this);
            this.destroy.connect(() => {
                refresh_every(-1);
                remove_all_series();
            });
        }

        public void add_serie(Serie serie) {
            this.series.register(serie);
        }

        public void remove_serie(Serie serie){
            this.series.remove_serie(serie);
        }

        public void remove_all_series(){
            this.series.remove_all();
        }

        [Version (deprecated = true, deprecated_since = "1.7.0", replacement = "Retrieve the Serie from Chart.series (or from the serie you created) and add the value using serie.add")]
        public void add_value(Serie serie, double value) {
            serie.add(value);
        }

        [Version (deprecated = true, deprecated_since = "1.7.0", replacement = "Retrieve the Serie from Chart.series and add the value using serie.add")]        
        public void add_value_by_index(int serie_index, double value) throws ChartError {
            try {
                var serie = series.get(serie_index);
                add_value(serie, value);
            } catch (ChartError e) {
                throw e;
            }
        }

        public void add_unaware_timestamp_collection(Serie serie, Gee.Collection<double?> collection, int timespan_between_value) {
            var ts = GLib.get_real_time() / 1000 - (collection.size * timespan_between_value);
            var values = serie.get_values();
            collection.foreach((value) => {
                ts += timespan_between_value;
                values.add({ts, value});
                config.y_axis.update_bounds(value);
                return true;
            });
        }

        public void add_unaware_timestamp_collection_by_index(int serie_index, Gee.Collection<double?> collection, int timespan_between_value) throws ChartError {
            try {
                var serie = series.get(serie_index);
                add_unaware_timestamp_collection(serie, collection, timespan_between_value);
            } catch (ChartError e) {
                throw e;
            }
        }

        public void to_png(string filename) throws Error {
#if GTK3
            var window = this.get_window();
            if (window == null) {
                throw new ChartError.EXPORT_ERROR("Chart is not realized yet");
            }
            var pixbuff = Gdk.pixbuf_get_from_window(window, 0, 0, window.get_width(), window.get_height());
            pixbuff.savev(filename, "png", {}, {});
#endif
        }

        public void refresh_every(int ms, double play_ratio = 1.0) {
            this.play_ratio = play_ratio;
            if (source_timeout != 0) {
                GLib.Source.remove(source_timeout); 
                source_timeout = 0;
            }
            if(ms > 0){
                this.prev_time = GLib.get_monotonic_time() / 1000;
                source_timeout = Timeout.add(ms, () => {
                    if(this.play_ratio != 0.0){
                        var now = GLib.get_monotonic_time() / 1000;
                        config.time.current += (int64)((now - this.prev_time) * this.play_ratio);
                        this.prev_time = now;
                    }
                    this.queue_draw();
                    return true;
                });
            }
        }

        public void aim_to_point(double x, double y, bool with_guide){
            this.pointing.point.x = x;
            this.pointing.point.y = y;
            this.pointing.guide = with_guide;
        }
        
        public bool get_aimed_value(out TimestampedValue tv){
            var tv_ = TimestampedValue();
            var ret = this.pointing.refer_plot_value(ref tv_, this.config, this.config.boundaries(), this.series);
            tv = tv_;
            return ret;
        }
        
        private bool render(Gtk.Widget _, Context ctx) {
            ctx.set_antialias(Cairo.Antialias.NONE);
            config.configure(ctx, legend);
            
            this.background.draw(ctx, config);
            this.grid.draw(ctx, config);
            if(this.legend != null) this.legend.draw(ctx, config);

            var boundaries = this.config.boundaries();
            foreach (Drawable serie in this.series) {
                ctx.rectangle(boundaries.x.min, boundaries.y.min, boundaries.x.max, boundaries.y.max);
                ctx.clip();
                serie.draw(ctx, this.config);
            }
            
            if(this.pointing.is_enabled()){
                var point = this.pointing.point;
                Gdk.RGBA color = {1.0f, 1.0f, 1.0f, 1.0f};
                ctx.set_source_rgba(color.red, color.green, color.blue, color.alpha);
                if(this.pointing.guide){
                    var tv = TimestampedValue();
                    
                    this.pointing.refer_plot_value(ref tv, this.config, boundaries, this.series);
                    
                    point = Points.value_to_point(tv, tv, this.config, boundaries, 0.0);
                    ctx.move_to(this.pointing.point.x, this.pointing.point.y);
                    ctx.show_text("[%s, %f]".printf(this.config.time.get_time_str((int64)tv.timestamp), tv.value));
                }
                ctx.move_to((double) boundaries.x.min, point.y);
                ctx.line_to((double) boundaries.x.max, point.y);
                ctx.move_to(point.x, (double) boundaries.y.min);
                ctx.line_to(point.x, (double) boundaries.y.max);
                ctx.stroke();
            }
            return false;
        }
    }
}
