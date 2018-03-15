module DrawNumber

using WebIO, Colors, Images, ImageMagick
using InteractNext, CSSUtil
using ImageFiltering, JSExpr



# using the string macro since for loops + ifs seem to make problems
const redraw = js"""
function redraw(context, brushsize, rect, drawtext){
    context.clearRect(0, 0, rect.height, rect.width); // Clears the canvas
    context.beginPath();

    context.strokeStyle = \"#000001\";
    context.lineJoin = "round";
    context.lineWidth = 6;
    var canvas = context.canvas;
    if(drawtext){
        context.font = \"30px Arial\";
        context.textAlign = \"center\";
        context.fillText(\"Draw here\", canvas.width/2, canvas.height/2);
    }

    context.rect(3, 3, rect.height-6, rect.width-6);
    context.stroke();
    context.lineWidth = brushsize;


    if(window.clickX.length > 0){
        for(var i=0; i < window.clickX.length; i++){
            context.beginPath();
            if(clickDrag[i] && i){
                context.moveTo(clickX[i-1], clickY[i-1]);
            }else{
                context.moveTo(clickX[i]-1, clickY[i]);
            }
            context.lineTo(clickX[i], clickY[i]);
            context.closePath();
            context.stroke();
        }
    }
}
"""

function drawnumber(;resolution = (400, 400), brushsize = 15, use_slider = false)
    drawandpredictnumber(
        nothing, resolution = resolution,
        image_button = "get image",
        brushsize = brushsize,
        use_slider = use_slider,
    )
end

function drawandpredictnumber(
        predict_func = (img)-> rand(0:9);
        resolution = (400, 400),
        brushsize = 15,
        use_slider = false,
        image_button = "predict:"
    )
    width, height = resolution

    w = Widget()
    painting = Observable{Bool}(w, "painting", false)
    paintbrush_ob = Observable(w, "paintbrush", brushsize)
    clear_obs = Observable(w, "clear_obs", false)
    getimage_ob = Observable(w, "getimage", 0)

    on_mousedown = @js function (e, context)
        $painting[] = true
        @var el = context.dom.querySelector("#surface")
        @var context = el.getContext("2d")
        @var rect = el.getBoundingClientRect();
        @var x = e.clientX - rect.left;
        @var y = e.clientY - rect.top;
        window.addclick(x, y, false);
        window.redraw(context, $paintbrush_ob[], rect, false);
    end
    on_mouseup = @js function (e, context)
        $painting[] = false
    end
    on_finish = @js function (e, context)
        $painting[] = false
    end
    on_mousemove = @js function (e, context)
        @var el = context.dom.querySelector("#surface")
        @var context = el.getContext("2d")
        @var rect = el.getBoundingClientRect();
        @var x = e.clientX - rect.left;
        @var y = e.clientY - rect.top;
        if $painting[]
            window.addclick(x, y, true);
            window.redraw(context, $paintbrush_ob[], rect, false);
        end
    end
    ondependencies(w, @js function ()
        window.clickX = @new Array()
        window.clickY = @new Array()
        window.clickDrag = @new Array()
        window.addclick = function (x, y, dragging)
            window.clickX.push(x);
            window.clickY.push(y);
            window.clickDrag.push(dragging);
        end
        window.redraw = $redraw
        @var el = this.dom.querySelector("#surface")
        @var context = el.getContext("2d")
        @var rect = el.getBoundingClientRect();
        window.redraw(context, $paintbrush_ob[], rect, true);
    end)
    canvas = w(dom"canvas#surface"(
        events = Dict(
            :mousemove => on_mousemove,
            :mousedown => on_mousedown,
            :mouseup => on_finish,
            :mouseleave => on_finish
        ),
        attributes = Dict(:height => "$(height)", :width => "$(width)")
    ))
    getimg = Observable(w, "getimg", false)
    image = Observable(w, "image", "")
    image_float = Observable(w, "image_float", ones(height, width))
    pred_widget = Widget()
    prediction_obs = Observable(pred_widget, "prediction", "")
    prediction_num_obs = Observable(pred_widget, "prediction num", 0)
    on(image) do img_str64
        if !isempty(img_str64)
            str = replace(img_str64, "data:image/png;base64,", "")
            ui8vec = base64decode(str)
            img = map(convert(Matrix{RGBA{N0f8}}, ImageMagick.load_(ui8vec))) do c
                Float64(alpha(c))
            end
            img = img[12:end-12, 12:end-12]
            sz = (28, 28)
            σ = map((o,n)->0.3*o/n, size(img), sz)
            kern = KernelFactors.gaussian(σ)  
            img = Gray.(Images.imresize(imfilter(img, kern, NA()), sz))
            # map!(img, img) do c
            #     if c > 0.4
            #         Images.clamp01(c + 0.2)
            #     else
            #         c
            #     end
            # end
            image_float[] = img
            if predict_func != nothing
                val = predict_func(img)
                if !isa(val, Integer)
                    error("Please return an integer from your prediction function. Found: $(typeof(val))")
                end
                prediction_num_obs[] = val
                prediction_str = val in 0:9 ? string(val) : ""
                prediction_obs[] = prediction_str
            end
        end
    end
    onjs(getimage_ob, @js function (val)
        @var el = this.dom.querySelector("#surface")
        @var data = el.toDataURL();
        $image[] = data
    end)
    onjs(prediction_obs, @js function (val)
        @var prediction_text = this.dom.querySelector("#prediction_text")
        prediction_text.textContent = val
    end)

    onjs(clear_obs, @js function (val)
        @var el = this.dom.querySelector("#surface")
        @var context = el.getContext("2d")
        window.clickX = [];
        window.clickY = [];
        window.clickDrag = [];
        $painting[] = false
        @var rect = el.getBoundingClientRect();
        window.redraw(context, $paintbrush_ob[], rect, true)
    end)

    onjs(paintbrush_ob, @js function (val)
        @var el = this.dom.querySelector("#surface")
        @var context = el.getContext("2d")
        @var rect = el.getBoundingClientRect();
        window.redraw(context, $paintbrush_ob[], rect, false)
    end)

    prediction_text = pred_widget(
        dom"div#prediction_text[class=md-subheading]"(
            "",
            style = Dict(:padding =>"10px 10px 10px 10px")
    ))
    paintbrushdiv = if use_slider
        paintbrush = slider(5:20, ob = paintbrush_ob)
        paintbrushdiv = dom"div"(
            paintbrush,
            style = Dict(:width => "$(round(Int, 1.5width))px")
        )
    else
        nothing
    end

    clear_butt = dom"button"("clear", events = Dict("click" => @js function ()
       $clear_obs[] = !$clear_obs[]
    end), style = Dict(:padding =>"10px 10px 10px 10px"))

    getimage_butt = dom"button"(image_button, events = Dict("click" => @js function ()
       $getimage_ob[] = !$getimage_ob[]
    end), style = Dict(:padding =>"10px 10px 10px 10px"))

    app = vbox(vbox(paintbrushdiv, hbox(clear_butt, getimage_butt, prediction_text)), canvas)
    if predict_func != nothing
        app, image_float, prediction_num_obs
    else
        app, image_float
    end
end

end

using .DrawNumber
using .DrawNumber: drawnumber, drawandpredictnumber

export drawandpredictnumber, drawnumber
