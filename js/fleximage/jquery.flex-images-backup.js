/*
	jQuery flexImages v1.0.1
    Copyright (c) 2014 Simon Steinberger / Pixabay
    GitHub: https://github.com/Pixabay/jQuery-flexImages
	License: http://www.opensource.org/licenses/mit-license.php
*/

(function($){
    $.fn.flexImages = function(options){
        var o = $.extend({ container: '.item', object: 'img', rowHeight: 180, maxRows: 0, truncate: false }, options);
        return this.each(function(){
            var $this = $(this), $items = $(o.container, $this), items = [], i = $items.eq(0), t = new Date().getTime();
            o.margin = i.outerWidth(true) - i.innerWidth();
            $items.each(function(){
                var w = parseInt($(this).data('w')),
                    h = parseInt($(this).data('h')),
                    isSolo = $(this).data('solo')                    
                    norm_w = w*(o.rowHeight/h), // normalized width
                    obj = $(this).find(o.object);
                items.push([$(this), w, h, norm_w, obj, obj.data('src'),isSolo]);
            });
            makeGrid($this, items, o);
            $(window).off('resize.flexImages'+$this.data('flex-t'));
            $(window).on('resize.flexImages'+t, function(){ makeGrid($this, items, o); });
            $this.data('flex-t', t)
        });
    }

    function makeGrid(container, items, o, noresize){
        var x, new_w, ratio = 1, rows = 1, max_w = container.width(), row = [], row_width = 0, row_h = o.rowHeight;
        // define inside makeGrid to access variables in scope
        function _helper(lastRow){
            if (o.maxRows && rows > o.maxRows || o.truncate && lastRow) row[x][0].hide();
            else {
                if (row[x][5]) { row[x][4].attr('src', row[x][5]); row[x][5] = ''; }
                row[x][0].css({ width: new_w, height: row_h }).show();
            }
        }
        function _isSolo(x){
            if (x.solo == "y" || x.solo=="yes" || x.solo=="1") {
                return true;
            }
            return false;
        }
        var _flush = false;
        for (i=0; i<items.length; i++) {
            if(_isSolo(items[i])) _flush=true;
            row.push(items[i]);
            row_width += items[i][3] + o.margin;
            if (row_width >= max_w  && _flush == true) {
                ratio = max_w / row_width;
                row_h = Math.ceil(o.rowHeight*ratio), exact_w = 0, new_w;
                for (x=0; x<row.length; x++) {
                    new_w = Math.ceil(row[x][3]*ratio);
                    exact_w += new_w + o.margin;
                    if (exact_w > max_w) new_w -= exact_w - max_w + 1;
                    _helper();
                }
               _flush=false;
                // reset for next row
                row = [], row_width = 0;
                rows++;
            }
        }
        // layout last row - match height of last row to previous row
        for (x=0; x<row.length; x++) {
            // if work needs to be done herem thats because images were added but did not
            // exceed the width of te container, had it exceeded, it would have been processed
            // in the above if condition block and row would be []
            // ratio = max_w / row_width;
            // only set ratio to ratio if aspect of image is <1
            row_h = Math.ceil(o.rowHeight*ratio), exact_w = 0, new_w;
            for (x=0; x<row.length; x++) {
                new_w = Math.ceil(row[x][3]*ratio);
                exact_w += new_w + o.margin;
                if (exact_w > max_w) new_w -= exact_w - max_w + 1;
                _helper();
            }
        }

        // scroll bars added or removed during rendering new layout?
        if (!noresize && max_w != container.width()) makeGrid(container, items, o, true);
    }
}(jQuery));
