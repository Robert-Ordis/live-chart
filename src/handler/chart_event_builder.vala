namespace LiveChart{
    
    internal delegate void PositionEvent(Gdk.Device? device, double x, double y);
    internal delegate void ClickEvent(Gdk.Device? device, double x, double y, uint btn_num);
    internal delegate void ScrollEvent(Gdk.Device? device, double dx, double dy);
    
    internal struct ChartEventPosition {
        double x;
        double y;
        uint btn;
        ChartEventPositionAttr attr;
    }
    
    internal enum ChartEventPositionAttr{
        PLOT_AREA,
        LEGEND_AREA,
        HORIZONTAL_GRID,
        VERTICAL_GRID,
        OUTSIDE
    }
    
    internal class ChartEventBuilder {
        
        private unowned Chart chart;
        internal ChartEventBuilder(Chart chart){
            this.chart = chart;
        }
        
        public void define_motion(PositionEvent callback){
#if GTK3
            this.chart.add_events(Gdk.EventMask.POINTER_MOTION_MASK);
            this.chart.motion_notify_event.connect((ev) => {
                //If without ctrl, then auto correct to actually plotting point.
                callback(ev.device, ev.x, ev.y);
                return false;
            });
            this.chart.add_events(Gdk.EventMask.LEAVE_NOTIFY_MASK);
            this.chart.leave_notify_event.connect((ev) => {
                //callback(null, double.NAN, double.NAN);
                return false;
            });
#endif
#if GTK4
            var ctrl = new Gtk.EventControllerMotion();
            chart.add_controller(ctrl);
            ctrl.leave.connect(() => {
                //callback(ctrl.get_current_event_device(), double.NAN, double.NAN);
            });
            ctrl.motion.connect((x, y) => {
                callback(ctrl.get_current_event_device(), x, y);
            });
#endif
        }
        
        public void define_clicked(ClickEvent? press, ClickEvent? release){
            
#if GTK3
            this.chart.add_events(Gdk.EventMask.BUTTON_PRESS_MASK | Gdk.EventMask.BUTTON_RELEASE_MASK);
            if(press != null){
                this.chart.button_press_event.connect((ev) => {
                    press(ev.device, ev.x, ev.y, ev.button);
                    return false;
                });
            }
            if(release != null){
                this.chart.button_release_event.connect((ev) => {
                release(ev.device, ev.x, ev.y, ev.button);
                return false;
                });
            }
#endif
#if GTK4
            var ctrl = new Gtk.GestureClick();
            ctrl.button = 0;
            this.chart.add_controller(ctrl);
            if(press != null){
                ctrl.pressed.connect((n, x, y) => {
                    press(ctrl.get_current_event_device(), x, y, ctrl.get_current_button());
                });
            }
            if(release != null){
                ctrl.released.connect((n, x, y) => {
                    release(ctrl.get_current_event_device(), x, y, ctrl.get_current_button());
                });
            }
#endif
        }
        
        public void define_scrolled(ScrollEvent callback){
#if GTK3
            this.chart.add_events(Gdk.EventMask.SCROLL_MASK | Gdk.EventMask.SMOOTH_SCROLL_MASK);
            this.chart.scroll_event.connect((ev) => {
                callback(ev.device, ev.delta_x, ev.delta_y);
                return false;
            });
#endif
#if GTK4
            var ctrl = new Gtk.EventControllerScroll(
                Gtk.EventControllerScrollFlags.BOTH_AXES
                | Gtk.EventControllerScrollFlags.KINETIC
            );
            this.chart.add_controller(ctrl);
            ctrl.scroll.connect((dx, dy) => {
                callback(ctrl.get_current_event_device(), dx, dy);
                return true;
            });
#endif
        }
        
    }
    
}