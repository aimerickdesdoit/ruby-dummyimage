require 'sinatra'
require 'RMagick'
require 'rvg/rvg'

FORMATS = {
  'png' => 'png',
  'gif' => 'gif',
  'jpg' => 'jpeg'
}

get '/' do
  erb :index
end

get '/:size' do
  width_height, format = params[:size].downcase.split('.')
  format = FORMATS[format] || 'png'

  width, height = width_height.split('x').map { |wat| wat.to_i }

  height = width unless height

  backgroundcolor = color_convert(params[:backgroundcolor]) || '#eeeeee'
  text_color = color_convert(params[:textcolor]) || '#aaaaaa'

  rvg = Magick::RVG.new(width, height).viewbox(0, 0, width, height) do |canvas|
    canvas.background_fill = backgroundcolor
  end
  
  # background
  images = nil
  dummy = rvg.draw
  dummy.format = format
  
  use_loader = format == 'gif' && params[:loader] != 'false'
  use_image = params[:image] == 'true' && !use_loader
  use_text = !use_image && !use_loader
  
  case true
    
    when use_text
      # text
      drawable = Magick::Draw.new
      drawable.pointsize = width / 10
      drawable.font = './DroidSans.ttf'
      drawable.fill = text_color
      drawable.gravity = Magick::CenterGravity
      drawable.annotate(dummy, 0, 0, 0, 0, "#{width} x #{height}")
  
    when use_image
      # image
      image = Magick::Image.read('images/image.png').first rescue nil
      image_width = width/4
      image_height = height/4
      if image
        image.resize_to_fit! image_width, image_height
        
        # merge
        flatten = Magick::ImageList.new
        flatten << dummy
        flatten << image
        image.change_geometry(Magick::Geometry.new(image_width, image_height)) do |x, y|
          flatten[1].page = Magick::Rectangle.new(0, 0, (width / 2) - (x / 2), (height / 2) - (y / 2))
        end
        dummy = flatten.flatten_images
      end
  
    when use_loader
      # animation
      images = Magick::ImageList.new('images/loader.gif')
      loader_width = width/4
      loader_height = height/4
      offset = nil
      images.each_with_index do |frame, index|
        unless offset
          frame.change_geometry(Magick::Geometry.new(loader_width, loader_height)) do |x, y|
            offset = Magick::Rectangle.new(0, 0, (width / 2) - (x / 2), (height / 2) - (y / 2))
          end
        end
        frame.resize_to_fit! loader_width, loader_height
        frame.page = offset
        flatten = Magick::ImageList.new
        flatten << dummy
        flatten << frame
        images[index] = flatten.flatten_images
      end
  end
  
  content_type "image/#{format}"
  if images
    images.to_blob
  else
    dummy.to_blob
  end

end

private

def color_convert(original)
  if original
    if original.index('!') == 0
      original.tr('!', '#')
    else
      original
    end
  end
end