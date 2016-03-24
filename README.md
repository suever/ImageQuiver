# ImageQuiver

This project is an image-based variant of MATLAB's built-in [quiver plot][1]. The `ImageQuiver` class creates a graphics object that behaves similarly to the built-in `quiver` graphics object except that it displays a user-defined image in place of the arrows that `quiver` uses by default.

This project was initially developed as a response to [a question][2] posed by [@jarhead][3] on [stackoverflow.com][4].

## Getting Started

### Creation

The inputs to `ImageQuiver` are identical to the inputs to `quiver` with the exception that the first input is the image data that is used in place of the arrow heads.

    h = ImageQuiver(CData, XData, YData, UData, VData, AutoScaleFactor);

**INPUTS**

|Name      | Data Type  | Description  |
|----------|------------|--------------|
|`CData`   | `char` or `double`  | Image data used in place of the `quiver` arrows. If a `char` is provided, it is assumed that this is a valid file path containing the image. If a numeric array is provided it can either be an indexed or RGB image. Any `NaN` values in the input image are treated as transparent pixels   | 
| `XData`  | `double`   | X coordinates of the start points of the quiver images   |  
| `YData`  | `double`   | Y coordinates of the start points of the quiver images   |  
| `UData`  | `double`   | Vector lengths in the X direction
| `VData`  | `double`   | Vector lengths in the Y direction
| `AutoScaleFactor`  | `double` | (Optional) Scalar indicating the scaling to apply to the displacements specified by `UData` and `VData`. The default value is `1.0`  | 
In addition to all of the inputs specified above, parameter/value pairs can be provided to specify the initial value for *any* of the properties of the graphics objects (i.e. the `Parent`).

**OUTPUTS**

|Name      | Data Type  | Description                                     |
|----------|------------|-------------------------------------------------|
|`h`   | `ImageQuiver`  | Handle to the `ImageQuiver` object which can be used to inspect or alter the appearance of the `ImageQuiver` plot. This behaves similar to all other MATLAB graphics objects.| 

### Manipulation

The `ImageQuiver` object behaves similarly to the built-in graphics objects. The properties that can affect the display of the object can be manipulated using either dot notation (`object.property`) or using the `set` and `get` methods.

```matlab
h.Visible = 'off';
set(h, 'ButtonDownFcn', @(s,e)disp('click!'))
cdata = h.CData;
set(h, 'CData', rand(32))
```

All parameters and their current value can be determined by either displaying the object (`disp`) or retrieving the parameters and values as a `struct` using `get`.

```matlab
get(h)

            AlphaData: []
           Annotation: [1x1 matlab.graphics.eventdata.Annotation]
      AutoScaleFactor: 1
         BeingDeleted: 'off'
           BusyAction: 'queue'
        ButtonDownFcn: @(s,e)disp('click!')
                CData: [32x32 double]
             Children: [0x0 GraphicsPlaceholder]
            CreateFcn: ''
            DeleteFcn: ''
          DisplayName: ''
     HandleVisibility: 'on'
              HitTest: 'on'
        Interruptible: 'on'
               Parent: [1x1 Axes]
        PickableParts: 'visible'
             Selected: 'off'
   SelectionHighlight: 'on'
                  Tag: ''
                 Type: 'ImageQuiver'
                UData: 1
        UIContextMenu: [0x0 GraphicsPlaceholder]
             UserData: []
                VData: 1
              Visible: 'off'
                XData: 1
                YData: 1
```

The graphics objects are refreshed on an as-needed basis.

### Removal

If you want to remove the `ImageQuiver` instance, you can simply delete either the parent `axes` or the object itself. This will remove the object and all associated graphics.

    delete(get(h, 'Parent'))
    delete(h)


## Examples

### Simple Example

Here we simply create a series of vectors pointing outward from a circle. We use the MATLAB logo in place of an arrow.

```matlab
t = linspace(0, 2*pi, 13); t(end) = [];
X = cos(t) * 3 + 5; Y = sin(t) * 3 + 5;
dX = cos(t);        dY = sin(t);

hax = axes();
colormap gray;

% Display an image underneath to show off transparency
imagesc(rand(9), 'Parent', hax);
set(hax, 'CLim', [-4 4])
hold(hax, 'on')
axis(hax, 'image')

% Plot some circles as references
tt = linspace(0, 2*pi, 100);
plot(cos(tt) * 3 + 5, sin(tt) * 3 + 5, 'Parent', hax)
plot(X, Y, 'o', 'MarkerFaceColor', 'w')

% Create the ImageQuiver object
img = fullfile(matlabroot, 'toolbox', 'matlab', 'icons', 'matlabicon.gif');
q = ImageQuiver(img, X, Y, dX, dY, 1, 'Parent',  hax);

% Retrieve the CData and make the transparent pixels equal to the upper left hand corner
cdata = get(q, 'CData');
set(q, 'AlphaData', any(cdata ~= cdata(1), 3))
```

![Simple Example][8]

### Animation

Any changes to the properties of the graphics object will automatically cause a refresh of the graphics; however, if you want the result to be displayed immediately, you need to use `drawnow` otherwise the rendering will be postponed until the processor is idle. This is displayed in this example as we update the object within a loop.

```matlab
% Rotate all vectors
theta = linspace(0, 2*pi, 30); theta(end) = [];

for k = 1:numel(theta)
     set(q, 'UData', dX * cos(theta(k)) - dY * sin(theta(k)), ...
            'VData', dX * sin(theta(k)) + dY * cos(theta(k)))
     drawnow
end
```

![Animated Example][9]

### Comparison With Quiver

The following example is taken directly from the documentation for `quiver`. This shows the differences between the two.

```matlab
% Example from the MATLAB quiver documentation
[X,Y] = meshgrid(-2:.2:2);
Z = X.*exp(-X.^2 - Y.^2);
[DX,DY] = gradient(Z,.2,.2);

figure

% Standard Quiver plot
ax1 = subplot(1,2,1);
quiver(X, Y, DX, DY, 'Parent', ax1);
title(ax1, 'Quiver')

% Image Quiver with the MATLAB logo
ax2 = subplot(1,2,2);
img = fullfile(matlabroot, 'toolbox', 'matlab', 'icons', 'matlabicon.gif');
q = ImageQuiver(img, X, Y, DX, DY, 'Parent', ax2);
title(ax2, 'ImageQuiver')

% Set transparency to top left pixel
cdata = get(q, 'CData');
set(q, 'AlphaData', any(cdata ~= cdata(1), 3))
```

![Comparison of quiver and ImageQuiver][10]

## Testing

A suite of unit tests is distributed with this software and can be run using the following command.

    results = ImageQuiver.test();

## Bug Reporting

Any issues or bugs should be reported to this project's [Github issue page][5].


## Attribution

Copyright &copy; <2016> [Jonathan Suever][6]  
All rights reserved.

This software is licensed under the [three-clause BSD license][7].


[1]: http://www.mathworks.com/help/matlab/ref/quiver.html
[2]: http://stackoverflow.com/a/36070755/670206
[3]: http://stackoverflow.com/users/1420894/jarhead
[4]: http://stackoverflow.com
[5]: https://github.com/suever/ImageQuiver/issues
[6]: https://github.com/suever
[7]: https://github.com/suever/ImageQuiver/blob/master/LICENSE
[8]: example.png
[9]: animated.gif
[10]: comparison.png
