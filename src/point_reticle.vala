namespace LiveChart {
    public class PointReticle {
        public Point point;
        public bool guide = false;
        
        private Gee.SortedSet<TimestampedValue?> workset;
        
        public PointReticle(){
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
        }
        
        public bool is_enabled(){
            return !this.point.x.is_nan() && !this.point.y.is_nan();
        }
        
        public bool refer_plot_value(ref TimestampedValue tv, Config config, Boundaries boundaries, Series series){
            if(!this.is_enabled()){
                return false;
            }
            tv = Points.point_to_value(this.point, config, boundaries);
            if(this.guide){
                
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
                
                
                var values = this.workset.tail_set(tv);
                if(values.size > 0){
                    var final_time = values.first().timestamp;
                    if(tv.timestamp < (final_time + (config.x_axis.tick_interval * config.time.conv_sec) / 8)){
                        tv = values.first();
                    }
                }
            }
            
            return true;
        }
        
        
    }
}