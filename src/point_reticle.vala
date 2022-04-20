using Cairo;

namespace LiveChart {
    public class PointReticle : Drawable, GLib.Object {
        //public members.
        public string name { get; private set; }
        
        //For Detecting nearest value from reticle.
        private Gee.SortedSet<TimestampedValue?> workset;
        public Serie? target_serie = null;
        
        //Parent Chart instance.
        internal unowned Chart? parent = null;
        
        //fundamental members
        private Point point;            //for representing x,y. TimestampedValue is calculated from this.
        private bool guide = false;    //If true, TimestampedValue will be adjusted to nearest ploting serie.
        public bool locked = false;    //If true, set_point will be ignored;
        
        //Rendering associated
        public Path line { get; set; }
        
        //Boiler plate
        protected BoundingBox bounding_box = BoundingBox(){ x = 0, y = 0, width = 0, height = 0};
        public BoundingBox get_bounding_box() { return this.bounding_box; }
        public bool visible { get; set; default = true; }
        
        internal PointReticle(string name = ""){
            this.name = name;
            this.point.x = double.NAN;
            this.point.y = double.NAN;
            this.workset = new Gee.TreeSet<TimestampedValue?>((a, b) => {
                if(a.value < b.value){
                    return -1;
                }
                else if(a.value > b.value){
                    return 1;
                }
                return 0;
            });
            this.line = new Path(1);
        }
        
        public void aim_to_point(double x, double y, bool guide){
            if(!this.locked){
                this.point.x = x;
                this.point.y = y;
                this.guide = guide;
            }
        }
        
        private bool check_inbounds(Config config, ref Boundaries boundaries){
            if(
                this.point.x.is_nan() ||
                this.point.y.is_nan() ||
                false
            ){
                return false;
            }
            
            boundaries = config.boundaries();
            if(boundaries.x.min > this.point.x || boundaries.x.max < this.point.x){
                return false;
            }
            if(boundaries.y.min > this.point.y || boundaries.y.max < this.point.y){
                return false;
            }
            
            return true;
        }
        
        private TimestampedValue get_aimed_value_(Config config, Boundaries boundaries){
            
            var tv = Points.point_to_value(this.point, config, boundaries);
            
            if(this.guide){
                
                if(this.target_serie != null){
                    //find nearest plot value to this reticle point.
                    var values = this.target_serie.get_values().tail_set(tv);
                    if(values.size > 0){
                        tv = values.first();
                    }
                    else if(this.target_serie.get_values().size > 0){
                        tv = this.target_serie.get_values().last();
                    }
                }
                else if(this.parent != null){
                    var series = this.parent.series;
                    
                    this.workset.clear();
                    
                    foreach(var serie in series){
                        Gee.SortedSet<TimestampedValue?> values = serie.get_values();
                        if(!serie.visible){
                            continue;
                        }
                        
                        values = values.tail_set(tv);
                        if(values.size <= 0){
                            continue;
                        }
                        
                        if(this.workset.size > 0){
                            var v = values.first();
                            if(this.workset.first().timestamp < v.timestamp){
                                this.workset.clear();
                            }
                        }
                        this.workset.add(values.first());
                    }
                    
                    if(this.workset.size > 0){
                        var values = this.workset.tail_set(tv);
                        var final_val = (values.size > 0) ? values.first() : this.workset.first();
                        if(tv.timestamp < (final_val.timestamp + (config.x_axis.tick_interval * config.time.conv_sec) / 8)){
                            tv = final_val;
                        }
                    }
                }
            }
            
            return tv;
        }
        
        public bool get_aimed_value(ref TimestampedValue tv){
            
            if(this.parent == null){
                return false;
            }
            
            var boundaries = Boundaries();
            if(!this.check_inbounds(this.parent.config, ref boundaries)){
                return false;
            }
            
            tv = this.get_aimed_value_(this.parent.config, boundaries);
            
            return true;
        }
        
        public void draw(Context ctx, Config config){
            if(!this.visible || this.parent == null){
                return;
            }
            var boundaries = Boundaries();
            
            if(!this.check_inbounds(config, ref boundaries)){
                return;
            }
            
            if(this.target_serie != null){
                this.target_serie.line.configure(ctx);
            }
            else{
                this.line.configure(ctx);
            }
            
            var tv = this.get_aimed_value_(config, boundaries);
            var plot_point = Points.value_to_point(tv, tv, config, boundaries, 0.0);
            
            ctx.move_to(this.point.x, this.point.y);
            ctx.show_text("%s[%s, %f]".printf(this.name, config.time.get_time_str((int64)tv.timestamp), tv.value));
            
            ctx.move_to((double) boundaries.x.min, plot_point.y);
            ctx.line_to((double) boundaries.x.max, plot_point.y);
            ctx.move_to(plot_point.x, (double) boundaries.y.min);
            ctx.line_to(plot_point.x, (double) boundaries.y.max);
            ctx.stroke();
        }
        
    }
}