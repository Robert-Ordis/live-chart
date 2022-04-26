using Cairo;

namespace LiveChart {
    public class PointReticle : GLib.Object {
        //public members.
        private string name_;
        public string name { 
            public get{ return name_; }
            private set {
                name_ = value;
                this.refresh_plotname();
            }
        }
        
        //For Detecting nearest value from reticle.
        private Gee.SortedSet<TimestampedValue?> workset;
        private Serie? target_serie_ = null;
        public Serie? target_serie {
            public get { return target_serie_; }
            public set {
                target_serie_ = value;
                this.refresh_plotname();
            }
        }
        
        //Parent Chart instance.
        internal unowned Chart? parent = null;
        
        //fundamental members
        private Point point;            //for representing x,y. TimestampedValue is calculated from this.
        private bool guide = false;    //If true, TimestampedValue will be adjusted to nearest ploting serie.
        public bool locked = false;    //If true, set_point will be ignored;
        
        //Rendering associated
        public Path line { get; set; }
        public bool visible = true;
        private string plot_name = "";
        
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
        
        internal void adjust_aiming(double dx, double dy, Config config){
            if(!this.point.x.is_nan()){
                this.point.x += dx;
            }
            
            if(!this.point.y.is_nan()){
                var boundaries = config.boundaries();
                var old_height = boundaries.height - dy;
                if(old_height != 0.0){
                    var diff = this.point.y - boundaries.y.min;
                    diff = diff / old_height * boundaries.height;
                    this.point.y = boundaries.y.min + diff;
                }
                else{
                    this.point.y = boundaries.y.min + boundaries.height / 2;
                }
            }
        }
        
        private bool check_inbounds(Boundaries boundaries){
            if(
                this.point.x.is_nan() ||
                this.point.y.is_nan() ||
                false
            ){
                return false;
            }
            
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
                        /// \todo Serie.get_nearest_values(timestamp, config, ref list);
                        ///            -> If I want to implement Candlestick chart, then the above func is necessary.
                        Gee.SortedSet<TimestampedValue?> values = serie.get_values();
                        if(!serie.visible){
                            continue;
                        }
                        
                        values = values.tail_set(tv);
                        if(values.size <= 0){
                            continue;
                        }
                        
/*
                        if(this.workset.size > 0){
                            var v = values.first();
                            if(this.workset.first().timestamp < v.timestamp){
                                this.workset.clear();
                            }
                        }
*/
                        this.workset.add(values.first());
                    }
                    
                    if(this.workset.size > 0){
                        var values = this.workset.tail_set(tv);
                        if(values.size <= 0){
                            values = this.workset;
                        }
                        foreach(var final_val in values){
                            if(tv.timestamp < (final_val.timestamp + (config.x_axis.tick_interval * config.time.conv_sec) / 8)){
                                tv = final_val;
                                break;
                            }
                        }
                    }
                }
            }
            
            return tv;
        }
        
        private void refresh_plotname(){
            var no_name = (this.name == null || this.name == "");
            var no_target = this.target_serie == null;
            if(no_name && no_target){
                this.plot_name = "";
            }
            else if(no_name){
                this.plot_name = "%s".printf(this.target_serie.name);
            }
            else if(no_target){
                this.plot_name = this.name;
            }
            else{
                this.plot_name = "%s->%s".printf(this.name, this.target_serie.name);
            }
        }
        
        public bool get_aimed_value(ref TimestampedValue tv){
            
            if(this.parent == null){
                return false;
            }
            
            var boundaries = this.parent.config.boundaries();
            
            if(!this.check_inbounds(boundaries)){
                return false;
            }
            
            tv = this.get_aimed_value_(this.parent.config, boundaries);
            
            return true;
        }
        
        internal bool draw_reticle(Context ctx, Config config, ReticleContext r_context){
            
            var boundaries = r_context.boundaries;
            if(!this.visible || this.parent == null){
                return false;
            }
            
            if(!this.check_inbounds(boundaries)){
                return false;
            }
            
            var tv = this.get_aimed_value_(config, boundaries);
            var plot_point = Points.value_to_point(tv, tv, config, boundaries, 0.0);
            
            if(this.target_serie != null){
                this.target_serie.line.configure(ctx);
            }
            else{
                this.line.configure(ctx);
            }
            
            var summary_txt = "%s[%s, %f]".printf(this.plot_name, config.time.get_time_str((int64)tv.timestamp), tv.value);
            if(this.locked){
                //locked: on point->only name
                //        on summary->both name and vals.
                ctx.move_to(r_context.pos_label.x, r_context.pos_label.y);
                ctx.show_text(summary_txt);
                ctx.move_to(0.0, plot_point.y);
                ctx.show_text(this.plot_name);
            }
            else{
                TextExtents extents = TextExtents();
                ctx.text_extents(summary_txt, out extents);
                var gap = (config.width - (this.point.x + extents.width));
                if(gap > 0){
                    gap = 0.0;
                }
                ctx.move_to(this.point.x + gap, this.point.y);
                ctx.show_text(summary_txt);
            }
            
            
            ctx.move_to(0.0, plot_point.y);
            ctx.line_to(config.width, plot_point.y);
            ctx.move_to(plot_point.x, (double) boundaries.y.min);
            ctx.line_to(plot_point.x, (double) boundaries.y.max);
            ctx.stroke();
            
            return true;
        }
        
        
    }
}