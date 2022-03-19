namespace LiveChart { 

    public class XAxis {

        public float tick_interval { get; set; default = 10;}
        public float tick_length { get; set; default = 60;}
        public bool visible { get; set; default = true; }
        public Labels labels = new Labels();
        public Path axis = new Path();
        public Path lines = new Path();

        public XAxis() {
            axis.color = {0.5f, 0.5f, 0.5f, 0.5f};
            lines.color = {0.5f, 0.5f, 0.5f, 0.2f};
        }

        public double get_ratio() {
            return tick_length / tick_interval;
        }
    }
    
    public struct Ticks {
        Gee.List<float?> values;
        public Ticks() {
            values = new Gee.ArrayList<float?>();
        }
    }

    public class YAxis {
        private Bounds bounds = new Bounds();
        private double ratio = 1;

        public float ratio_threshold { get; set; default = 1.118f;}
        public float tick_interval { get; set; default = 60;}
        public bool visible { get; set; default = true; }

        public Labels labels = new Labels();
        public Path axis = new Path();
        public LiveChart.Path lines = new LiveChart.Path();

        [Version (deprecated = true, deprecated_since = "1.0.0b7")]        
        public float tick_length { get; set; default = 60;}
        public string unit { get; set; default = "";}

        [Version (deprecated = true, deprecated_since = "1.0.0b7", replacement = "ratio is always smart ;)")]
        public bool smart_ratio = false;

        public double? fixed_max;
        public Ticks ticks;

        public YAxis(string unit = "") {
            this.unit = unit;
            ticks = get_ticks();
            axis.color = {0.5f, 0.5f, 0.5f, 0.5f};            
            lines.color = {0.5f, 0.5f, 0.5f, 0.2f};            
            bounds.notify["upper"].connect(() => {
                this.ticks = get_ticks();
            });
            bounds.notify["lower"].connect(() => {
                this.ticks = get_ticks();
            });
        }

        public double get_ratio() {
            return this.ratio;
        }

        public Bounds get_bounds() {
            return new Bounds(this.bounds.lower, this.bounds.upper);
        }

        public bool update_bounds(double value) {
            return this.bounds.update(value);
        }

        public void update(int area_height) {
            var distance = bounds.upper;
			if(ticks.values.size > 0){
				distance -= ticks.values[0];
			}
			else{
				distance -= bounds.lower;
			}
            if (distance != 0.0f && this.fixed_max == null) {
                this.ratio = (double) area_height / (distance * ratio_threshold);
            }
            
            if (this.fixed_max != null) {
                this.ratio = (double) area_height / ((double) this.fixed_max);
            }
        }

        public string get_max_displayed_value() {
            if (ticks.values.size > 0) {
                string max_displayed_value = format_for_y_axis(unit, ticks.values.first());
                foreach(float value in ticks.values) {
                    string formatted_value = format_for_y_axis(unit, value);
                    if (formatted_value.length >= max_displayed_value.length) {
                        max_displayed_value = formatted_value;
                    }
                }
                return max_displayed_value;
            }

            return unit;
        }

        public Ticks get_ticks() {
            var ticks = Ticks();
            if (fixed_max != null) {
                for (var value = 0f; value <= fixed_max; value += tick_interval) {
                    ticks.values.add(value);
                }

                return ticks;
            }
            float distance = LiveChart.cap((float)(bounds.upper - bounds.lower));
            float upper = LiveChart.cap((float)bounds.upper);
            float lower = -LiveChart.cap((float)bounds.lower.abs());
            
            //float distance = (upper >= lower.abs()) ? upper : lower.abs();
            
            var divs = LiveChart.golden_divisors(distance);

            if (divs.size > 0) {
                float interval = distance / divs.get(0);
                foreach(float div in divs) {
                    interval = distance / div;
                    if (div > 3f && div < 7f) {
                        break;
                    }
                }
                var limit = (bounds.upper == upper) ? upper : bounds.upper + interval;
                for (var value = 0f; value <= limit; value += interval) {
                    ticks.values.add(value);
                }
                
                //limit = (bounds.lower == lower) ? lower : bounds.lower - interval;
				
				if(bounds.lower < 0.0){
					limit = (bounds.lower);
					for(var value = -interval; value > limit; value -= interval){
						ticks.values.add(value);
					}
					ticks.values.add((float)limit);
					ticks.values.sort((a, b) => {
						var r = a - b;
						if(r < 0){return -1;}
						if(r > 0){return 1;}
						return 0;
					});
				}

                
            }
        
            /*
            if (bounds.has_upper()) {
                float upper = LiveChart.cap((float) bounds.upper);
                var divs = LiveChart.golden_divisors(upper);

                if (divs.size > 0) {
                    float interval = upper / divs.get(0);
                    foreach(float div in divs) {
                        interval = upper / div;
                        if (div > 3f && div < 7f) {
                            break;
                        }
                    }
                    var limit = bounds.upper == upper ? upper : bounds.upper + interval;
                    for (var value = 0f; value <= limit; value += interval) {
                        ticks.values.add(value);
                    }
                }
            }
            */

            return ticks;
        }
    }
}
