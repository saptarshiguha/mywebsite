/*
	jQuery flexImages v1.0.1
    Copyright (c) 2014 Simon Steinberger / Pixabay
    GitHub: https://github.com/Pixabay/jQuery-flexImages
	License: http://www.opensource.org/licenses/mit-license.php
    
    data-solo  = image placed by itself
    data-sqz   = force image to be in same row as currently being formed
    data-flush = flush the current row with this  image
    
    Images are placed one by one till the exceed the width
    and then a new row is formed.
    
*/

(function($){
    $.fn.flexImages = function(options){
        var o = $.extend({ container: '.item', object: 'img', rowHeight: 180, maxRows: 0, truncate: false }, options);
        return this.each(function(){
            var $this = $(this), $items = $(o.container, $this), items = [], i = $items.eq(0), t = new Date().getTime();
            o.margin = i.outerWidth(true) - i.innerWidth();
            console.log("Hello")
            console.log([i.outerWidth(true), i.innerWidth(), i.outerWidth(true) - i.innerWidth()]);
            $items.each(function(){
                var w = parseInt($(this).data('w')),
                    h = parseInt($(this).data('h')),
                    isSolo = $(this).data('solo') ;  
                    flush =   $(this).data('flush')  ;             
                    sqz = $(this).data('sqz') ;                  
                    norm_w = w*(o.rowHeight/h), // normalized width
                    obj = $(this).find(o.object);
                items.push([$(this), w, h, norm_w, obj, obj.data('src'),{flush:flush,solo:isSolo,sqz:sqz}]);
            });
            makeGrid($this, items, o);
            $(window).off('resize.flexImages'+$this.data('flex-t'));
            $(window).on('resize.flexImages'+t, function(){ makeGrid($this, items, o); });
            $this.data('flex-t', t)
            console.log($this);
        });
    }

    function makeGrid(container, items, o, noresize){
        var x, new_w, ratio = 1, rows = 1, max_w = container.width(), row = [], row_width = 0, row_h = o.rowHeight;
        
        // define inside makeGrid to access variables in scope
        function _helper(lastRow, rows, rr, nw, rh) {
            console.log([nw, rh]);
            if (o.maxRows && rows > o.maxRows || o.truncate && lastRow) rr[x][0].hide();
            else {
                if (rr[x][5]) { rr[x][4].attr('src', rr[x][5]); rr[x][5] = ''; }
                rr[x][0].css({ width: nw, height: rh }).show();
            }
        }
        function _isSolo(x){
            if (x.solo== "y" || x.solo=="yes" || x.solo=="1") {
                return true;
            }
            return false;
        }
        function doFlush(r,w,myrows){
            ratio = max_w / w;
            row_h = Math.ceil(o.rowHeight*ratio), exact_w = 0, new_w;
            for (x=0; x<r.length; x++) {
                    new_w = Math.ceil(r[x][3]*ratio);
                    exact_w += new_w + o.margin;
                    if (exact_w > max_w) new_w -= exact_w - max_w + 1;
                    console.log(r);
                    _helper(false,myrows, r,new_w, row_h);
                }  
        }
       var i = 0; 
       while(i < items.length) {
            if(_isSolo(items[i][6])) {
                //console.log("Item is Solo"+items[i])
                if (row.length > 0) {
                    if (row_width == 0) row_width = items[i][3] + o.margin;
                   doFlush(row, row_width);
                   row = [], row_width = 0;
                   rows++;
               }
               doFlush( [ items[i]], items[i][3]+o.margin,rows);
               rows++;
               i = i+1;
            } else {
                console.log("SBEGUNG")
                console.log(items[i]) 
                row.push(items[i]);
                row_width += items[i][3] + o.margin;
                i = i+1;
                if (row_width >= max_w || (items[i] != undefined && items[i][6].flush=="y") ){
                    // about to flush
                    j = i;
                    if(!(items[i] != undefined && items[i][6].flush=="y")){
                        console.log("Does not have a flush")
                    if(j< (items.length-1)){
                        while(true){
                                var tt = items[j];
                                if(tt[6].sqz=="y"){
                                    row.push(tt);
                                    row_width += tt[3] + o.margin;
                                }else break
                                j = j+1;  
                        }
                    }
                    }else { console.log("Last Image was a flush, flush NOW")}
                    doFlush(row, row_width,rows);
                    row = [], row_width = 0;
                    rows++;
                    i = j;
                } // else { i = i+1;}
            }
        }
        // layout last row - match height of last row to previous row
        if(row.length>0){
            doFlush(row, row_width);
        }

        // scroll bars added or removed during rendering new layout?
        if (!noresize && max_w != container.width()) makeGrid(container, items, o, true);
    }
}(jQuery));
