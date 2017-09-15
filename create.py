filenames = "/tmp/images.csv"
lines = open(filenames).readlines()[1:]
lines = [x.rstrip() for x in lines]
lines = [ x.split(",") for x in lines]

def info(lp):
    easyname = lp[0]
    secname  = lp[1].split("&")
    return (easyname, secname[0])

lines = [ info(x) for x in lines]


webtemplate="index.template"
templ = open(webtemplate).read()


substring = """
            <div class="col-lg-3 col-md-4 col-xs-6 thumb">
                <a class="thumbnail" href="#">
                    <img class="img-responsive" width="{size}"  src="{gimage}" alt="{nicename}">
                </a>
                 <div class='chx'>
                 <input  type="checkbox" id="{v}" data-myimgurlg="{gimage}" value="">
                 </div>
            </div>
"""

news = []
for i,l in enumerate(lines):
    x = substring.format(size="300",v="image{}".format(i),gimage = l[1], nicename = l[0])
    news.append(x)
news = "\n".join(news)

code="""
    <script>
      $(function() {
           $('input:checkbox').change(function() {
             console.log($(this))
           })
          $('#gen').on('click', function (e) {
            var selected = [];
            $('#foo input:checked').each(function() {
              selected.push($(this).prop('dataset').myimgurlg);
             });
            var txt = selected.join("\\n");
            $("#filenamelist").val(txt);
       })

      })

    </script>

"""

templstring = templ.format(SUBS=news,codeins=code)

with open("./index.html", "w") as text_file:
    text_file.write(templstring)







