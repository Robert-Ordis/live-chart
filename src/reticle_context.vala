using Cairo;

namespace LiveChart{
    //Role: An organizer of PointReticle.
    //In the fact: If I want to draw the reticle's actual value in one table, then an organizer is necessary to do.
    internal class ReticleContext : Drawable, Gee.ArrayList<PointReticle> {
        
        //Rendering member
        internal Boundaries boundaries;
        internal Point pos_label;
        private Point pos_init;
        private double font_height = 0;
        Font font = new Font();
        
        //Boiler plate
        protected BoundingBox bounding_box = BoundingBox(){ x = 0, y = 0, width = 0, height = 0};
        public BoundingBox get_bounding_box() { return this.bounding_box; }
        public bool visible { get; set; default = true; }
        
        
        internal ReticleContext(double init_x, double init_y){
            base();
            this.pos_init.x = init_x;
            this.pos_init.y = init_y;
            this.set_font(this.font);
        }
        
        public new bool add(PointReticle reticle){
            bool ret = base.add(reticle);
            
            return ret;
        }
        
        public void set_font(Font font){
            var ctx = new Context(new ImageSurface(Cairo.Format.ARGB32, 16, 16));
            TextExtents extents;
            this.font = font;
            this.font.configure(ctx);
            ctx.text_extents("I", out extents);
            this.font_height = extents.width + 3.0;
        }
        
        public void draw(Context ctx, Config config){
            
            this.boundaries = config.boundaries();
            this.pos_label = pos_init;
            this.font.configure(ctx);
            //ctx.text_extents("I", out extent);
            this.pos_label.y += font_height;
            foreach(var reticle in this){
                if(reticle.draw_reticle(ctx, config, this)){
                    //reticle has been drawn->decide where next summary will be drawn.
                    this.pos_label.y += font_height;
                }
            }
            
        }
        
    }
}