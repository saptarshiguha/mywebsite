# http://stackoverflow.com/questions/19169849/how-to-get-markdown-processed-content-in-jekyll-tag-plugin
require 'json'
def parseparam(markup)
  markup =  markup.strip!
  markup = markup.gsub(/\s*=\s*/m,'=')
  markup = markup.split("=")
  varlist = Hash.new
  (0..markup.length-1).step(2) do |n|
    varlist[ markup[n] ] = markup[n+1]
  end
  varlist
end

module Jekyll
  class JrnlTag < Liquid::Block
    @title = nil

    def initialize(tag_name, markup, tokens)
      @title = "col-lg-4 col-md-6 col-xs-10  col-sm-10 col-centered"
      if markup.to_s != '' then
        markup = parseparam(markup)
        if markup['width'].to_s != '' then
          @title = markup['width']
          if @title == "code" then
            @title = 'col-lg-6 col-md-6 col-xs-10  col-sm-10 col-centered'
          end
        end
      end
      super
    end

    def render(context)
        text = super
        site = context.registers[:site]
        converter = site.find_converter_instance(::Jekyll::Converters::Markdown)
        output = converter.convert(super(context))
        x = "
<div class='row row-centered '><div class='#{@title}'>
<div class='jrnl'>
        #{output}
</div>          
</div></div>
"
        x
    end
  end
end
Liquid::Template.register_tag('jrnl', Jekyll::JrnlTag)



# http://stackoverflow.com/questions/19169849/how-to-get-markdown-processed-content-in-jekyll-tag-plugin
module Jekyll
  class PoemTag < Liquid::Block
    @title = nil

    def initialize(tag_name, markup, tokens)
      @title = markup
      super
    end

    def render(context)
        text = super
        site = context.registers[:site]
        converter = site.find_converter_instance(::Jekyll::Converters::Markdown)
        output = converter.convert(super(context))
        "
<div class='poem'>
        #{output}
</div>
"
    end
  end
end

Liquid::Template.register_tag('poem', Jekyll::PoemTag)


module Jekyll
  class WidePic < Liquid::Tag

    def initialize(tag_name, text, tokens)
      super
      @text = text
    end

    def render(context)
      output = Liquid::Template.parse(@text).render(context)
      "<div class='row'> <img  class='bannerimg' src='#{output}'></div>"
    end
  end
end

Liquid::Template.register_tag('widepic', Jekyll::WidePic)


module Jekyll
  class ImgTileTag < Liquid::Block
    @pnc = 2
    @pw = 8
    @bootsz = @pw/@pnc
    
    def initialize(tag_name, markup, tokens)
      markup =  markup.strip!
      markup = markup.gsub(/\s*=\s*/m,'=')
      markup = markup.gsub(/\s+/m, ' ').gsub(/^\s+|\s+$/m, '').split(" ")
      for par in markup
        par2 = par.split("=")
        if par2[0] == "nc"
          @pnc = par2[1].to_i
          if @pnc == 12
            raise "nc is 12, consider using widepic"
          end
        elsif par2[0] == "w"
          @pw = par2[1].to_i
        else
          raise "Illegal Parameter passed: "+ par +" \n"
        end
      end
      @bootsz = @pw / @pnc
      super
    end


    def render(context)
        text = super
        site = context.registers[:site]
        imges = super(context).strip!.gsub(/' '+/m, ' ').split("\n")
        myoo = Array.new
        for img in imges
          thum = nil
          orig = nil
          pair = img.split(" ")
          if pair.length == 2
            thum = pair[0]
            orig = pair[1]
          else
            thum = pair[0]
            orig = pair[0]
          end
          myoo << "<div class=\"col-md-#@bootsz col-centered\" style='vertical-align: middle;'>\n<a  href='#{orig}'><img class='img=responsive center-block' style='padding-left:2px;padding-right:2px' src='#{thum}'/> </a></div>"
        end
        oos =  myoo.length.to_i
        nrows = oos / @pnc
        #print "Nrows=#{nrows} , imges=#{oos}\n"
        if ( oos  % @pnc) != 0
          raise "Number of images: #{myoo.length} is not a multiple of number of columns: #{@nc}\n"+super(context)
        end
        oo2 = []
        for i in 0 .. nrows-1
          s = "<div class='row row-centered tile'>\n"
          for j in 0 .. @pnc-1
            s = s + myoo[j+i*@pnc] + "\n"
          end
          s=s+"</div>\n"
          oo2 << s
        end
        oo2.join("\n")
    end
  end
end

Liquid::Template.register_tag('imgtile', Jekyll::ImgTileTag)



module Jekyll
  class RenderTimeTag < Liquid::Tag

    def initialize(tag_name, text, tokens)
      super
      @text = text
    end

    def render(context)
      "<strong>#{@text} #{ Time.now.strftime("%H:%M %d %b, %Y")}</strong>"
    end
  end
end

Liquid::Template.register_tag('now', Jekyll::RenderTimeTag)



module Jekyll
  class SwirlTag < Liquid::Tag

    def initialize(tag_name, text, tokens)
      super
      @text = text
    end

    def render(context)
      "
<div class='row'> <div class='col-xs-12 row-centered'><div class='swirl'></div></div></div>
"
    end
  end
end

Liquid::Template.register_tag('swirl', Jekyll::SwirlTag)



module Jekyll
  class ImgTileTag2 < Liquid::Block
    @pnc = 2
    @pw = 8
    @bootsz = @pw/@pnc
    
    def initialize(tag_name, markup, tokens)
      markup =  markup.strip!
      markup = markup.gsub(/\s*=\s*/m,'=')
      markup = markup.gsub(/\s+/m, ' ').gsub(/^\s+|\s+$/m, '').split(" ")
      for par in markup
        par2 = par.split("=")
        if par2[0] == "nc"
          @pnc = par2[1].to_i
          if @pnc == 12
            raise "nc is 12, consider using widepic"
          end
        elsif par2[0] == "w"
          @pw = par2[1].to_i
        else
          raise "Illegal Parameter passed: "+ par +" \n"
        end
      end
      @bootsz = @pw / @pnc
      super
    end


    def render(context)
        text = super
        site = context.registers[:site]
        imges = super(context).strip!.gsub(/' '+/m, ' ').split("\n")
        myoo = Array.new
        for img in imges
          thum = nil
          orig = nil
          pair = img.split(" ")
          if pair.length == 2
            thum = pair[0]
            orig = pair[1]
          else
            thum = pair[0]
            orig = pair[0]
          end
          myoo << "<div class=\"col-md-#@bootsz col-centered\" style='padding:0;margin:0;vertical-align: middle;'>\n<a  href='#{orig}'><img class='img=responsive center-block' style='margin:0;padding:0;' src='#{thum}'/> </a></div>"
        end
        oos =  myoo.length.to_i
        nrows = oos / @pnc
        #print "Nrows=#{nrows} , imges=#{oos}\n"
        if ( oos  % @pnc) != 0
          raise "Number of images: #{myoo.length} is not a multiple of number of columns: #{@nc}\n"+super(context)
        end
        oo2 = []
        for i in 0 .. nrows-1
          s = "<div class='row row-centered tile2' style='margin:0;padding:0;'>\n"
          for j in 0 .. @pnc-1
            s = s + myoo[j+i*@pnc] + "\n"
          end
          s=s+"</div>\n"
          oo2 << s
        end
        oo2.join("\n")
    end
  end
end

Liquid::Template.register_tag('imgtileNoSpace', Jekyll::ImgTileTag2)
