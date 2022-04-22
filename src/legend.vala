using Cairo;

namespace LiveChart {
    
     public abstract class Legend : Drawable, Object {

        public bool visible { get; set; default = true; }
        public Labels labels = new Labels();

        protected Gee.ArrayList<Serie> series = new Gee.ArrayList<Serie>();
        protected BoundingBox bounding_box = BoundingBox() {
            x=0, 
            y=0, 
            width=0,
            height=0
        };
        public Gdk.RGBA main_color { 
            get; set; 
            default= Gdk.RGBA() {
                red = 1.0f,
                green = 1.0f,
                blue = 1.0f,
                alpha = 1.0f
            };
        }
        public void add_legend(Serie serie) {
            series.add(serie);
        }
        public void remove_legend(Serie serie){
            if(series.contains(serie)){
                series.remove(serie);
            }
        }
        public void remove_all_legend(){
            series.clear();
        }
        
        public abstract void draw(Context ctx, Config config);
        public BoundingBox get_bounding_box() {
            return bounding_box;
        }
        
        public abstract void slide_list(double delta);
        public abstract bool is_focused(double x, double y, Config config);
        public abstract Serie? get_clicked_serie(double x, double y, Config config);
        
    }

     public class HorizontalLegend : Legend {
        
        private const int COLOR_BLOCK_WIDTH = 15;
        private const int COLOR_BLOCK_HEIGHT = 10;

        private const int EACH_BLOCK_PADDING = 20;
        
        private double gap = 0.0;
        
        private Context dummy_ctx = new Context(new Cairo.ImageSurface (Cairo.Format.ARGB32, 16, 16));
        
        public override void draw(Context ctx, Config config) {
            if (visible) {
                
                var y_padding = get_y_padding(config);
                var boundaries = config.boundaries();
                var pos = (int)this.gap;
                series.foreach((serie) => {
                    ctx.set_source_rgba(serie.main_color.red, serie.main_color.green, serie.main_color.blue, 1);
                    ctx.rectangle(boundaries.x.min + pos, boundaries.y.max + y_padding, COLOR_BLOCK_WIDTH, COLOR_BLOCK_HEIGHT);
                    ctx.fill();
                    
                    labels.font.configure(ctx);
                    TextExtents extents = name_extents(serie.name, ctx);
                    ctx.move_to(boundaries.x.min + pos + COLOR_BLOCK_WIDTH + 3, boundaries.y.max + y_padding + extents.height + (COLOR_BLOCK_HEIGHT - extents.height) / 2);
                    ctx.show_text(serie.name);

                    pos += COLOR_BLOCK_WIDTH + (int) extents.width + EACH_BLOCK_PADDING;

                    return true;
                });
                ctx.stroke();
                this.update_bounding_box(config, pos);
                this.debug(ctx);
            }
        }
   
        private int get_y_padding(Config config) {
            return (int) (Grid.ABSCISSA_TIME_PADDING * 2 + config.x_axis.labels.extents.height);
        }

        private TextExtents name_extents(string name, Context ctx) {
            TextExtents name_extents;
            ctx.text_extents(name, out name_extents);

            return name_extents;
        }

        private void update_bounding_box(Config config, int width) {
            var boundaries = config.boundaries();
            this.bounding_box = BoundingBox() {
                x=boundaries.x.min,
                y=boundaries.y.max + get_y_padding(config),
                width=width,
                height=10
            };
        }

        protected void debug(Context ctx) {
            var debug = Environment.get_variable("LIVE_CHART_DEBUG");
            if(debug != null) {
                ctx.rectangle(bounding_box.x, bounding_box.y, bounding_box.width, bounding_box.height);
                ctx.stroke();
            }
        }
        
        public override void slide_list(double delta) {
            this.gap += delta;
            if(this.gap > 0.0){
                this.gap = 0.0;
            }
        }
        public override bool is_focused(double x, double y, Config config) {
            var boundaries = config.boundaries();
            var y_min = get_y_padding(config) + boundaries.y.max;
            var y_max = y_min + COLOR_BLOCK_HEIGHT;
            return (y_min <= y && y <= y_max); 
        }
        public override Serie? get_clicked_serie(double x, double y, Config config) { 
            //var y_padding = get_y_padding(config);
            var boundaries = config.boundaries();
            
            var pos = this.gap + boundaries.x.min;
            foreach(var serie in this.series){
                labels.font.configure(this.dummy_ctx);
                TextExtents extents = name_extents(serie.name, this.dummy_ctx);
                var width = (double)COLOR_BLOCK_WIDTH + extents.width + EACH_BLOCK_PADDING;
                var pos_max = pos + width;
                
                //print("getting serie[%s]: %f <-> %f <-> %f(%f)\n".printf(serie.name, pos, x, pos_max, extents.width));
                if((pos <= x && x <= pos_max)){
                    return serie;
                }
                
                pos = pos_max;
            }
            return null;
        }
        
    }

    public class NoopLegend : Legend {
        public override void draw(Context ctx, Config config) {}
        public override void slide_list(double delta) {}
        public override bool is_focused(double x, double y, Config config) { return false; }
        public override Serie? get_clicked_serie(double x, double y, Config config) { return null; }
    }
}