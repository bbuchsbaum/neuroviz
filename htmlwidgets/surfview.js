function toRadians(angle) {
	return angle * (Math.PI / 180);
}

function toDegrees(angle) {
	return angle * (180 / Math.PI);
}


function mouse_listener(renderer, geometry) {
  var isDragging = false;

  var previousMousePosition = {
    x: 0,
    y: 0
  };


  $(renderer.domElement).on('mousedown', function(e) {
    isDragging = true;
  })

  $(renderer.domElement).on('mouseup', function(e) {
    isDragging = false;
  })

  .on('mousemove', function(e) {
    console.log(e);
    var deltaMove = {
        x: e.offsetX-previousMousePosition.x,
        y: e.offsetY-previousMousePosition.y
    };

    if(isDragging) {

        var deltaRotationQuaternion = new THREE.Quaternion()
            .setFromEuler(new THREE.Euler(
                toRadians(deltaMove.y * 1),
                toRadians(deltaMove.x * 1),
                0,
                'XYZ'
            ));

        geometry.quaternion.multiplyQuaternions(deltaRotationQuaternion, geometry.quaternion);
    }

    previousMousePosition = {
        x: e.offsetX,
        y: e.offsetY
    };
  });
}


function setupControls(el, viewer, irange) {
   // Create the GUI
    var gui = new guify({
      title: 'Test App',
      theme: 'dark', // dark, light, yorha, or theme object
      align: 'right', // left, right
      width: 300,
      barMode: 'offset', // none, overlay, above, offset
      panelMode: 'inner',
      opacity: 0.95,
      root: el,
      open: true
    });


    gui.Register({
      type: 'select',
      label: 'View',
      options: ['lateral', 'medial', 'posterior', 'anterior'],
      onChange: (data) => {
        viewer.setView(data);
      }
    });

    gui.Register({
      type: 'select',
      label: 'Color Map',
      options: ['jet', 'summer', 'hot', 'cool',
      'spring', 'bluered'],
      onChange: (data) => {
        console.log("new map is ", data)
        viewer.setColorMap(SurfaceViewer.ColorMap[data]);
      }
    });

    gui.Register({
          type: 'range',
          label: 'Threshold',
          min:  0,
          max:  Math.max(Math.abs(irange[0]), Math.abs(irange[1])),
          initial:0,
          onChange: (data) => {
            var t = Math.abs(data)
            viewer.setThreshold(-t,t);
          }
    });

    gui.Register({
          type: 'range',
          label: 'Contrast',
          min: 0,
          max: 100,
          initial:0,

          onChange: (data) => {
            var frac = data/100;
            console.log(frac);
            viewer.setContrast(frac);
          }
      });

}


HTMLWidgets.widget({

  name: "threetest",

  type: "output",

  factory: function(el, width, height) {
    var viewer;

    return {
      renderValue: function(x) {
        console.log(x.curvature);

        var surf = new SurfaceViewer.NeuroSurface(x.vertices, x.indices,
        x.data, x.color_map, [0,0], [], x.curvature);

        console.log(surf);
        viewer = new SurfaceViewer.SurfaceViewer({ left: surf },
          parseInt(width), parseInt(height));

        el.appendChild(viewer.renderer.domElement);
        viewer.render();

        var irange = viewer.getIntensityRange();
        setupControls(el, viewer, irange);

      },

      resize: function(width, height) {
        console.log("resizing", width, " ", height);
        viewer.setSize(width,height);
      },

      viewer: viewer,
      width: parseInt(width),
      height: parseInt(height),

    };
  }
});

