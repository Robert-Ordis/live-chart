using Gee;

namespace LiveChart {
    
    public struct TimestampedValue {
        public double timestamp;
        public double value;
    }

    public class Values : TreeSet<TimestampedValue?> {
        public Bounds bounds {
            get; construct set;
        }
 
        private int buffer_size;
        
        public static int cmp(TimestampedValue? a, TimestampedValue? b){
            double r = a.timestamp - b.timestamp;
            if(r < 0.0){
                return -1;
            }
            if(r > 0.0){
                return 1;
            }
            return 0;
        }
        public Values(int buffer_size = 1000) {
            base(cmp);
            this.bounds = new Bounds();
            this.buffer_size = buffer_size;
        }
/*
        public new TimestampedValue @get(int index){
            assert (index >= 0);
            assert (index < buffer_size);
            int i = 0;
            TimestampedValue ret = {};
            this.foreach((v) => {
                if(i == index){
                    ret = v;
                    return false;
                }
                i++;
                return true;
            });
            return ret;
        }
        
*/
        public bool add_all_ts(SortedSet<TimestampedValue?> c, out double upper, out double lower){
            upper = 0.0;
            lower = 0.0;
            if(c == null || c.size <= 0){
                return false;
            }
            //print("start iterate\n");
            foreach(var tv in c){
                if(tv.value > upper){
                    upper = tv.value;
                }
                else if(tv.value < lower){
                    lower = tv.value;
                }
                base.add(tv);
            }
            //print("end_iterate\n");
            bounds.update(upper);
            bounds.update(lower);
            //var r = base.add_all(c);
            var r = true;
            if(this.buffer_size > 0){
                while(this.size > this.buffer_size){
                    this.remove(this.first());
                }
            }
            return r;
        }
        
        public new void add(TimestampedValue value) {
            if (this.size == buffer_size) {
                //this.remove_at(0);
                this.remove(this.first());
            }
            bounds.update(value.value);
            base.add(value);
        }
    }
}