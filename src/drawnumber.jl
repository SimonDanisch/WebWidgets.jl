module DrawNumber

using WebIO, Colors, Images, ImageMagick
using InteractNext, CSSUtil

# using the string macro since for loops + ifs seem to make problems
const redraw = js"""
function redraw(context, brushsize){
    context.clearRect(0, 0, 200, 200); // Clears the canvas
    context.beginPath();

    context.strokeStyle = \"#000001\";
    context.lineJoin = "round";
    context.lineWidth = 3;

    context.rect(0, 0, 200, 200);
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

function drawnumber(predict_func = (img)-> rand(0:9), resolution = (200, 200))
    width, height = resolution

    w = Widget()
    painting = Observable{Bool}(w, "painting", false)
    paintbrush_ob = Observable(w, "paintbrush", 10)
    paintbrush = slider(1:20, ob = paintbrush_ob, direction = "vertical")
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
            window.redraw(context, $paintbrush_ob[]);
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
        window.redraw(context, $paintbrush_ob[]);
    end)
    canvas = w(dom"canvas#surface[height=200,width=200]"(
        events = Dict(
            :mousemove => on_mousemove,
            :mousedown => on_mousedown,
            :mouseup => on_finish,
            :mouseleave => on_finish
        )
    ))
    clear_obs = Observable(w, "clear_obs", false)
    getimg = Observable(w, "getimg", false)
    image = Observable(w, "image", "")
    pred_widget = Widget()
    prediction_obs = Observable(pred_widget, "prediction", "")
    canvas_image = Matrix{RGBA{N0f8}}(width, height)
    on(image) do img_str64
        if !isempty(img_str64)
            str = replace(img_str64, "data:image/png;base64,", "")
            ui8vec = base64decode(str)
            img = convert(Matrix{RGBA{N0f8}}, ImageMagick.load_(ui8vec))
            val = predict_func(img)
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
        window.redraw(context, $paintbrush_ob[])
    end)

    clear = dom"button"("clear", events = Dict("click" => @js function ()
       $clear_obs[] = !$clear_obs[]
    end))

    predict = dom"button"("predict", events = Dict("click" => @js function ()
       $getimg[] = !$getimg[]
    end))

    prediction_text = pred_widget(dom"div#prediction_text"(""))

    vbox(hbox(clear, predict, prediction_text), hbox(paintbrush, canvas))
end

end

using .DrawNumber
using .DrawNumber: drawnumber

export drawnumber
