using Cairo;

public class ClkTest {
    Gee.Map<int, int> map = new Gee.TreeMap<int, int>();
    public void show(){
        print("=============\n");
        double total = 0.0;
        double count = 0.0;
        foreach(var e in map.entries){
            print("[%2d: %03d] ".printf(e.key, e.value));
            total += (double)(e.key * e.value);
            count += (double)e.value;
        }
        print("\ncount: %f, total: %f, ave: %f\n".printf(count, total, total/count));
        print("====/\n");
    }
    public void count(int c){
        if(this.map.has_key(c)){
            this.map[c] = this.map[c] + 1;
        }
        else{
            this.map[c] = 1;
        }
    }
}

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
        
        private ReticleContext reticles = new ReticleContext(2, 2);
        
        
        public signal void on_legend_clicked(Gdk.Device device, Serie? serie, uint btn_num);
        public signal void on_chart_clicked(Gdk.Device device, double x, double y, uint btn_num);
        public signal void on_chart_motioned(Gdk.Device device, double x, double y);
        public signal void on_chart_scrolled(Gdk.Device device, double dx, double dy);
        
        private Gee.Map<Gdk.Device, ChartEventPosition?> click_pos = new Gee.HashMap<Gdk.Device, ChartEventPosition?>();
        private Gee.Map<Gdk.Device, ChartEventPosition?> moved_pos = new Gee.HashMap<Gdk.Device, ChartEventPosition?>();
        
        public Chart(Config config = new Config()) {
            this.config = config;

#if GTK3
            this.size_allocate.connect((allocation) => {
                var dx = allocation.width - this.config.width;
                var dy = allocation.height - this.config.height;
                this.config.height = allocation.height;
                this.config.width = allocation.width;
                foreach(var reticle in this.reticles){
                    reticle.adjust_aiming(dx, dy, this.config);
                }
            });
            this.draw.connect(render);
#endif            
#if GTK4
            this.set_draw_func((_, ctx, width, height) => {
                var dx = width - this.config.width;
                var dy = height - this.config.height;
                this.config.height = height;
                this.config.width = width;
                foreach(var reticle in this.reticles){
                    reticle.adjust_aiming(dx, dy, this.config);
                }
                this.render(_, ctx);
            });
#endif

            this.refresh_every(100);

            series = new Series(this);
            this.destroy.connect(() => {
                refresh_every(-1);
                remove_all_series();
                foreach(var r in this.reticles){
                    r.parent = null;
                    r.target_serie = null;
                }
                this.reticles.clear();
            });
            
            var builder = new ChartEventBuilder(this);
            builder.define_motion((device, x, y) => {
                ChartEventPosition curr = {x, y, 0, this.get_position_attribute(x, y)};
                if(curr.attr == ChartEventPositionAttr.PLOT_AREA){
                    this.on_chart_motioned(device, x, y);
                }
                else if(this.moved_pos.has_key(device)){
                    if(this.moved_pos[device].attr == ChartEventPositionAttr.PLOT_AREA){
                        this.on_chart_motioned(device, double.NAN, double.NAN);
                    }
                }
                this.moved_pos[device] = curr;
            });
            
            builder.define_clicked(
                (device, x, y, btn) => {
                    this.click_pos[device] = {x, y, btn, this.get_position_attribute(x, y)};
                },
                (device, x, y, btn) => {
                    if(!this.click_pos.has_key(device)){
                        return;
                    }
                    var prev = this.click_pos[device];
                    var attr = this.get_position_attribute(x, y);
                    this.click_pos.unset(device);
                    
                    if(prev.attr != attr || prev.btn != btn){
                        return;
                    }
                    
                    switch(attr){
                    case PLOT_AREA:
                        this.on_chart_clicked(device, x, y, btn);
                        break;
                    case LEGEND_AREA:
                        this.on_legend_clicked(device, this.legend.get_clicked_serie(x, y, this.config), btn);
                        break;
                    default:
                        break;
                    }
                    
                }
            );
            
            builder.define_scrolled((device, dx, dy) => {
                if(!this.moved_pos.has_key(device)){
                    return;
                }
                var pos = this.moved_pos[device];
                switch(pos.attr){
                case PLOT_AREA:
                    this.on_chart_scrolled(device, dx, dy);
                    break;
                case LEGEND_AREA:
                    this.legend.slide_list(dy * 4);
                    break;
                default:
                    break;
                }
            });
            
        }
        
        ~Chart(){
            print("Chart::destructor\n");
        }
        
        private ChartEventPositionAttr get_position_attribute(double x, double y){
            
            //LEGEND_AREA
            do{
                if(this.legend.is_focused(x, y, this.config)){
                    return ChartEventPositionAttr.LEGEND_AREA;
                }
            }while(false);
            
            //PLOT_AREA
            do{
                var boundaries = this.config.boundaries();
                if(x < boundaries.x.min || boundaries.x.max < x){
                    break;
                }
                if(y < boundaries.y.min || boundaries.y.max < y){
                    break;
                }
                return ChartEventPositionAttr.PLOT_AREA;
            }while(false);
            
            //OUTSIDE
            return ChartEventPositionAttr.OUTSIDE;
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
        
        public PointReticle new_point_reticle(string name){
            var ret = new PointReticle(name);
            ret.parent = this;
            this.reticles.add(ret);
            
            return ret;
        }
        
        public void refresh_now(){
            this.queue_draw();
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
                        config.time.current += (int64)((now - this.prev_time) * this.config.time.conv_ms * this.play_ratio);
                        this.prev_time = now;
                    }
                    this.queue_draw();
                    return true;
                });
            }
        }
        
        private bool render(Gtk.Widget _, Context ctx) {
            
            var boundaries = this.config.boundaries();
            
            ctx.set_antialias(Cairo.Antialias.NONE);
            config.configure(ctx, legend);
            
            this.background.draw(ctx, config);
            this.grid.draw(ctx, config);
            if(this.legend != null) this.legend.draw(ctx, config);
            
            reticles.draw(ctx, config);
            
            ctx.rectangle(boundaries.x.min, boundaries.y.min, boundaries.width, boundaries.height);
            ctx.clip();
            foreach (Drawable serie in this.series) {
                ctx.new_path();
                serie.draw(ctx, this.config);
            }
            return false;
        }
    }
}
