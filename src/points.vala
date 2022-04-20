using Gee;

namespace LiveChart {
    
     public struct Point {
        public double x;
        public double y;
        public double height;
    }
    
    public class Points : Object {

        private Gee.ArrayList<Point?> points = new Gee.ArrayList<Point?>();
        public Bounds bounds {
            get; construct set;
        }

        public Points() {
            this.bounds = new Bounds();
        }

        public void add(Point point) {
            bounds.update(point.y);
            points.add(point);
        }

        public int size {
            get {
                return points.size;
            }
        }

        public double realtime_delta {
            get; set;
        }

        public new Point get(int at) {
            return points.get(at);
        }

        public Point after(int at) {
            if (at + 1 >= size) return this.get(size - 1);
            return this.get(at + 1);
        }

        public Point first() {
            return this.get(0);
        }

        public Point last() {
            return this.get(this.size - 1);
        }

        public static Points create(Values values, Config config) {
            var boundaries = config.boundaries();

            Points points = new Points();
            if (values.size > 1) {
                /// \note SortedSet<G>.sub_set won't work as I expected correctly.
                TimestampedValue border = {(double)config.time.current + 1, 0.0};
                TimestampedValue lower = {border.timestamp - config.time.head_offset, 0.0};
                SortedSet<TimestampedValue?> renderee = null;
/*
                var renderee = values.head_set(border);
                if(config.time.head_offset >= 0.0 && renderee.size > 0){
                    border.timestamp -= config.time.head_offset;
                    if(renderee.first().timestamp < border.timestamp){
                        renderee = renderee.tail_set(border);
                    }
                }
*/
                if(config.time.head_offset > 0.0 && values.first().timestamp < lower.timestamp){
                    renderee = values.sub_set(lower, border);
                }
                else{
                    renderee = values.head_set(border);
                }
                if(renderee.size <= 1){
                    return points;
                }
                var last_value = renderee.last();
                //points.realtime_delta = (((GLib.get_real_time() / 1000) - last_value.timestamp) * config.x_axis.get_ratio()) / 1000;
                //points.realtime_delta = ((config.time.current - last_value.timestamp) * config.x_axis.get_ratio()) / 1000;
                foreach (TimestampedValue value in renderee) {
                    var point = Points.value_to_point(last_value, value, config, boundaries, points.realtime_delta);
                    points.add(point);
                }
            }
         
            return points;
        }

        private static Point value_to_point(TimestampedValue last_value, TimestampedValue current_value, Config config, Boundaries boundaries, double realtime_delta) {
            double y_min = 0.0;
            if(config.y_axis.ticks.values.size > 0){
                y_min = config.y_axis.ticks.values[0];
            }
            return Point() {
                //x = (boundaries.x.max - (last_value.timestamp - current_value.timestamp) / 1000 * config.x_axis.get_ratio()) - realtime_delta,
                x = (boundaries.x.max - (config.time.current - current_value.timestamp) 
                    * config.x_axis.get_ratio() / config.time.conv_sec),
                y = boundaries.y.max - ((current_value.value - y_min) * config.y_axis.get_ratio()),
                height = current_value.value * config.y_axis.get_ratio()
            };
        }
        
        public static TimestampedValue point_to_value(Point point, Config config, Boundaries boundaries){
            var ret = TimestampedValue();
            var y_min = 0.0;
            if(config.y_axis.ticks.values.size > 0){
                y_min = config.y_axis.ticks.values[0];
            }
            
            ret.timestamp = (double)config.time.current 
                - (boundaries.x.max - point.x) * config.time.conv_sec / config.x_axis.get_ratio();
            ret.value = y_min
                + (boundaries.y.max - point.y) / config.y_axis.get_ratio();
            
            return ret;
        }
        
    }
}