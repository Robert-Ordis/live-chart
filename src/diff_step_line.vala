using Cairo;

namespace LiveChart {
    public class DiffStepLine : SerieRenderer {
        
        public DiffStepLine(Values values = new Values()){
            base();
            this.values = values;
        }
        
        public override void draw(Context ctx, Config config) {
            if (visible) {
                var points = Points.create_raw(values, config);
                if (points.size > 0) {
                    this.draw_line(points, ctx, config);
                    ctx.stroke();
                }
            }
        }
        
        protected Points draw_line(Points points, Context ctx, Config config) {
            line.configure(ctx);
            
            int pos = 0;
            this.update_bounding_box(points, config);
            this.debug(ctx);
            var boundaries = config.boundaries();
            //ctx.move_to(first_point.x, first_point.y);
            for (; pos < points.size - 1; pos++){
                if(!this.is_out_of_area(points.get(pos))){
                    break;
                }
            }
            if(pos > 0){
                pos--;
            }
            var first_point = points.get(pos);
            var next_finish = false;
            ctx.move_to(first_point.x, first_point.y);
            if(this.values.size == 1){
                ctx.move_to(first_point.x, boundaries.y.min);
                ctx.line_to(first_point.x, boundaries.y.max);
                return points;
            }
            for (; pos < points.size -1; pos++) {
                var current_point = points.get(pos);
                var next_point = points.after(pos);
                if (this.is_out_of_area(current_point)) {
                    if(next_finish){
                        break;
                    }
                    next_finish = true;
                }
                var diff = Point() {
                    x = next_point.x - current_point.x,
                    y = next_point.y - current_point.y
                };
                ctx.move_to(current_point.x + 2, current_point.y - 2);
                ctx.show_text("dx=%.3f".printf(diff.x / config.x_axis.get_ratio()));
                ctx.move_to(current_point.x, current_point.y);
                ctx.line_to(next_point.x, current_point.y);
                if(diff.y.abs() > 8.0f){
                    ctx.move_to(next_point.x + 2, current_point.y - 2);
                    ctx.show_text("dy=%.3f".printf(diff.y / config.y_axis.get_ratio()));
                }
                ctx.move_to(next_point.x, current_point.y);
                ctx.line_to(next_point.x, next_point.y);
            }

            return points;
        }

        private void update_bounding_box(Points points, Config config) {
            this.bounding_box = BoundingBox() {
                x=points.first().x,
                y=points.bounds.lower,
                width=points.last().x - points.first().x,
                height=points.bounds.upper - points.bounds.lower
            };
        }
        
        
    }
}