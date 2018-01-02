module DrawNumber

using WebIO, Colors, Images, ImageMagick
using InteractNext, CSSUtil

# using the string macro since for loops + ifs seem to make problems
const redraw = js"""
function redraw(context, brushsize, rect){

    context.clearRect(0, 0, rect.height, rect.width); // Clears the canvas
    context.beginPath();

    context.strokeStyle = \"#000001\";
    context.lineJoin = "round";
    context.lineWidth = 3;

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

function drawnumber(predict_func = (img)-> rand(0:9); resolution = (200, 200))
    width, height = resolution

    w = Widget()
    painting = Observable{Bool}(w, "painting", false)
    paintbrush_ob = Observable(w, "paintbrush", 10)
    paintbrush = slider(1:20, ob = paintbrush_ob)
    on_mousedown = @js function (e, context)
        $painting[] = true
        @var el = context.dom.querySelector("#surface")
        @var context = el.getContext("2d")
        @var rect = el.getBoundingClientRect();
        @var x = e.clientX - rect.left;
        @var y = e.clientY - rect.top;
        window.addclick(x, y, false);
        window.redraw(context, $paintbrush_ob[]);
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
            window.redraw(context, $paintbrush_ob[], rect);
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
        window.redraw(context, $paintbrush_ob[], rect);
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
    clear_obs = Observable(w, "clear_obs", false)
    getimg = Observable(w, "getimg", false)
    image = Observable(w, "image", "")
    pred_widget = Widget()
    prediction_obs = Observable(pred_widget, "prediction", "")
    on(image) do img_str64
        if !isempty(img_str64)
            str = replace(img_str64, "data:image/png;base64,", "")
            ui8vec = base64decode(str)
            img = map(convert(Matrix{RGBA{N0f8}}, ImageMagick.load_(ui8vec))) do color
                a = alpha(color)
                if a ≈ 0.0
                    return 1.0
                else
                    Float64(red(color))
                end 
            end
            val = predict_func(img)
            if !isa(val, Integer)
                error("Please return an integer from your prediction function. Found: $(typeof(val))")
            end
            prediction_str = val in 0:9 ? string(val) : ""
            prediction_obs[] = prediction_str
        end
    end
    onjs(getimg, @js function (val)
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
        window.redraw(context, $paintbrush_ob[], rect)
    end)

    onjs(paintbrush_ob, @js function (val)
        @var el = this.dom.querySelector("#surface")
        @var context = el.getContext("2d")
        @var rect = el.getBoundingClientRect();
        window.redraw(context, $paintbrush_ob[], rect)
    end)

    clear = dom"button"("clear", events = Dict("click" => @js function ()
       $clear_obs[] = !$clear_obs[]
    end))

    predict = dom"button"("predict", events = Dict("click" => @js function ()
       $getimg[] = !$getimg[]
    end))

    prediction_text = pred_widget(dom"div#prediction_text"(""))
    paintbrushdiv = dom"div"(
        paintbrush,
        style = Dict(:width => "$(round(Int, 1.5width))px")
    )
    vbox(vbox(paintbrushdiv, hbox(clear, predict, prediction_text)), canvas)
end

end

using .DrawNumber
using .DrawNumber: drawnumber

export drawnumber
