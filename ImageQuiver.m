classdef ImageQuiver < hgsetget & dynamicprops
    % ImageQuiver - Image-based quiver plot
    %
    %   This class creates a graphics object that behaves similarly to the
    %   built-in quiver plot except that it displays a user-defined image
    %   rather than the arrows that quiver uses by default.
    %
    %   This project was initially developed as a response to a user's
    %   question on StackOverflow: http://stackoverflow.com/a/36070755/670206
    %
    % USAGE:
    %   q = ImageQuiver(cdata, xdata, ydata, udata, vdata, scale, ...)
    %
    % INPUTS:
    %   cdata:  Image, Image data to be displayed in place of the arrows.
    %           This image can be either indexed or RGB. Any NaN will be
    %           treated as a transparent pixel unless the AlphaData is also
    %           specified.
    %
    %   xdata:  [M x N] Numeric Array, X coordinates of the starting point
    %
    %   ydata:  [M x N] Numeric Array, Y coordinates of the starting points
    %
    %   udata:  [M x N] Numeric Array, Vector lengths in the X direction
    %
    %   vdata:  [M x N] Numeric Array, Vector lengths in the Y direction
    %
    %   scale:  Scalar, (optional) Scaling factor to be applied to the
    %           UData and VData (Default = 1)
    %
    %   ...:    Param/Value Pairs, Parameter/value pairs specifying the
    %           value of any other property of the object
    %
    % OUTPUTS:
    %   q:      Handle, ImageQuiver object which can be used to manipulate
    %           the appearance of the graphic.

    % Copyright (c) <2016> Jonathan Suever (suever@gmail.com)
    % All rights reserved
    %
    % This software is licensed under the 3-clause BSD license.

    properties (SetObservable = true)
        AlphaData               % Transparency matrix
        AutoScaleFactor = 1     % Scaling applied along direction vector
        CData                   % Image data to use for display
        UData                   % X Component of direction vector
        VData                   % Y Component of direction vector
        XData                   % X Component of vector starting point
        YData                   % Y Component of vector starting point
    end

    properties (SetAccess = 'private')
        Type  = 'ImageQuiver'   % Overloaded handle graphics type
    end

    properties (Hidden, Access = 'protected')
        group                   % Handle to the hggroup object
        surfaces                % Handles to all of the surface objects
        listener                % Listener for plot object deletion
        setting = false         % Flag to prevent refreshing
    end

    methods
        function self = ImageQuiver(varargin)
            % ImageQuiver - Constructor for an ImageQuiver object
            %
            % USAGE:
            %   q = ImageQuiver(cdata, xdata, ydata, udata, vdata, scale, ...)
            %
            % INPUTS:
            %   cdata:  Image, Image data to be displayed in place of the
            %           arrows. This image can be either indexed or RGB.
            %           Any NaN will be treated as a transparent pixel
            %           unless the AlphaData is also specified.
            %
            %   xdata:  [M x N] Numeric Array, X coordinates of the
            %           starting point
            %
            %   ydata:  [M x N] Numeric Array, Y coordinates of the
            %           starting points
            %
            %   udata:  [M x N] Numeric Array, Vector lengths in the X
            %           direction
            %
            %   vdata:  [M x N] Numeric Array, Vector lengths in the Y
            %           direction
            %
            %   scale:  Scalar, (optional) Scaling factor to be applied to
            %           the UData and VData (Default = 1)
            %
            %   ...:    Param/Value Pairs, Parameter/value pairs specifying
            %           the value of any other property of the object
            %
            % OUTPUTS:
            %   q:      Handle, ImageQuiver object which can be used to
            %           manipulate the appearance of the graphic.

            ip = inputParser();
            ip.KeepUnmatched = true;
            ip.addRequired('CData', @self.validateImage);
            ip.addRequired('XData', @isnumeric);
            ip.addRequired('YData', @isnumeric);
            ip.addRequired('UData', @isnumeric);
            ip.addRequired('VData', @isnumeric);
            ip.addOptional('AutoScaleFactor', self.AutoScaleFactor, ...
                            @(x)isscalar(x) && isnumeric(x))
            ip.addParamValue('Parent', gca, @(x)ishghandle(x, 'axes'));
            ip.parse(varargin{:});

            self.group = hggroup('Parent', ip.Results.Parent);

            % Now go through the hggroup and add all the properties here
            props = fieldnames(get(self.group));

            for k = 1:numel(props)
                % Ignore if the property is already defined
                if ~isempty(self.findprop(props{k})); continue; end

                % Add a dynamic property and assign setters/getters that
                % will relay properties between the two objects
                prop = self.addprop(props{k});
                prop.SetMethod = @(s,v)setwrapper(s,prop,v);
                prop.GetMethod = @(s,e)getwrapper(s,prop);
            end

            % If the underlying graphics object is deleted, follow suit
            self.listener = addlistener(self.group, ...
                'ObjectBeingDestroyed', @(s,e)delete(self));

            % Finally consider all input arguments
            set(self, ip.Results, ip.Unmatched)
        end

        function set(self, varargin)
            % Overloaded set method that ensures a refresh

            % Remember what the setting was
            orig = self.setting;

            % Ensure we don't trigger any pre-mature refreshes
            self.setting = true;
            set@hgsetget(self, varargin{:})

            % Re-enable refreshing
            self.setting = orig;

            % Actually force a refresh
            self.refresh()
        end

        function delete(self)
            % delete - Delete the plot object when this object is removed
            %
            % USAGE:
            %   self.delete()

            if ishghandle(self.group)
                delete(self.group)
            end
        end

        function refresh(self)
            % refresh - Redraw the quiverpic plot
            %
            % USAGE:
            %   self.refresh()

            % If we're using set(obj, params), ignore until we're done
            % setting all properties
            if self.setting; return; end

            % By default, use NaN in the CData to indicate transparency
            if isempty(self.AlphaData)
                alpha = ~isnan(self.CData(:,:,1));
            else
                alpha = self.AlphaData;
            end

            % Check the size of all of the inputs
            refsize = size(self.XData);

            if ~isequal(refsize, size(self.YData)) || ...
               ~isequal(refsize, size(self.UData)) || ...
               ~isequal(refsize, size(self.VData));
                warning(sprintf('%s:DimensionWarning', mfilename), ...
                    'Unable to render due to dimension mismatch');

                % If they are invalid, just hide the plots for now
                set(self.surfaces, 'Visible', 'off')
                return
            end

            % Determine aspect ratio of the source image
            sz = size(self.CData);

            % Create/Delete Surfaces as needed
            nSurfaces = numel(self.XData);
            nMissing = nSurfaces - numel(self.surfaces);

            if nMissing > 0
                self.surfaces = cat(2, self.surfaces, gobjects(1, nMissing));
            elseif nMissing < 0
                delete(self.surfaces(end:end + nMissing +1))
                self.surfaces = self.surfaces(1:nSurfaces);
            end

            % Check to ensure validity of all surfaces
            invalidSurfs = ~ishghandle(self.surfaces, 'surface');

            if any(invalidSurfs)
                self.surfaces(invalidSurfs) = gobjects(1, sum(invalidSurfs));
            end

            % Determine angle for displacement vectors and add pi/2 to make
            % the positive y direction "up"
            thetas = atan2(self.VData(:), self.UData(:)) + pi/2;
            thetas = reshape(thetas, 1, 1, []);
            [xx,yy] = meshgrid([-0.5, 0.5] * sz(2) / sz(1), [0 1]);

            % Scale depending on the magnitude of displacement vector
            scale = self.AutoScaleFactor;
            scales = scale * sqrt(self.UData(:).^2 + self.VData(:).^2);
            scales = reshape(scales, 1, 1, []);

            xx = bsxfun(@mtimes, xx, scales);
            yy = bsxfun(@mtimes, yy, scales);

            cosine = cos(thetas);
            sine = sin(thetas);

            % Rotate the surface by the specified angles
            xdata = bsxfun(@mtimes, xx, cosine) - ...
                    bsxfun(@mtimes, yy, sine);

            ydata = bsxfun(@mtimes, xx, sine) + ...
                    bsxfun(@mtimes, yy, cosine);

            % Shift so that we are at the XData/YData location
            xoffset = reshape(self.XData, 1, 1, []) - mean(xdata(2,:,:), 2);
            yoffset = reshape(self.YData, 1, 1, []) - mean(ydata(2,:,:), 2);

            xdata = bsxfun(@plus, xdata, xoffset);
            ydata = bsxfun(@plus, ydata, yoffset);

            for k = 1:size(xdata, 3)

                % If the surface handle is not valid, create a new one
                if invalidSurfs(k)
                    self.surfaces(k) = surf( ...
                        xdata(:,:,k), ydata(:,:,k), zeros(2), ...
                        'HandleVisibility', 'off', ...
                        'Parent', self.group);
                else
                    % Update surface plot appearance with new data
                    set(self.surfaces(k), ...
                            'XData', xdata(:,:,k), ...
                            'YData', ydata(:,:,k), ...
                            'ZData', zeros(2));
                end
            end

            % Update the remainder of the surface properties
            set(self.surfaces, ...
                'HandleVisibility', 'off', ...
                'FaceColor', 'texture', ...
                'EdgeColor', 'none', ...
                'CData', self.CData, ...
                'Visible', 'on', ...
                'FaceAlpha', 'texture', ...
                'AlphaData', double(alpha));

            % Check the alpha limits
            set(self.Parent, 'ALim', [0 1])
        end

        function disp(self)
            % Ensure that properties are displayed in alphabetical order
            getdisp(self)
        end

        function getdisp(self)
            % Ensure that properties are displayed in alphabetical order
            disp(orderfields(get(self)))
        end
    end

    % Get/Set Methods
    methods
        function set.AlphaData(self, value)
            assert(isnumeric(value) || islogical(value), ...
                   'AlphaData must be numeric')
            self.AlphaData = double(value);
            self.refresh();
        end

        function set.AutoScaleFactor(self, value)
            assert(isnumeric(value) && isscalar(value), ...
                'Scaling factor must be a scalar');
            self.AutoScaleFactor = value;
            self.refresh();
        end

        function set.CData(self, value)
            value = self.validateImage(value);
            self.CData = value;
            self.refresh();
        end

        function set.UData(self, value)
            assert(isnumeric(value), 'UData must be numeric')
            self.UData = double(value);
            self.refresh();
        end

        function set.VData(self, value)
            assert(isnumeric(value), 'VData must be numeric')
            self.VData = double(value);
            self.refresh();
        end

        function set.XData(self, value)
            assert(isnumeric(value), 'XData must be numeric')
            self.XData = double(value);
            self.refresh();
        end

        function set.YData(self, value)
            assert(isnumeric(value), 'YData must be numeric')
            self.YData = double(value);
            self.refresh();
        end
    end

    % These methods automatically translate the properties between the
    % underlying object and the current object
    methods (Access = 'protected')
        function setwrapper(self, prop, value)
            % Relays "set" events to the underlying object
            set(self.group, prop.Name, value)
        end

        function res = getwrapper(self, prop)
            % Relays "get" events to the underlying object
            res = get(self.group, prop.Name);
        end

        function varargout = validateImage(self, img)
            % validateImage - Method for checking for valid image data
            %
            %   Image data can be in the form of a file path, URL, or a
            %   numeric array. This function attempts to load the image,
            %   check the alpha data, and returns an error if there are any
            %   issues.

            if ischar(img)
                [img, map, alpha] = imread(img);

                if ~isempty(map) && size(img, 3) == 1
                    img = ind2rgb(img, map);
                end

                if ~isempty(alpha)
                    self.setting = true;
                    set(self.AlphaData, alpha)
                    self.setting = false;
                end
            end

            % Ensure that an image is numeric and indexed or RGB
            assert(isnumeric(img) && ( ismatrix(img) || ...
                ndims(img) == 3 && size(img, 3) == 3), ...
                'CData must be either Indexed or RGB')

            % Only return an output if one is requested
            if nargout; varargout = {img}; end
        end
    end

    methods (Static)
        function results = test(varargin)
            % test - Run all unittests for the ImageQuiver class
            %
            % USAGE:
            %   results = ImageQuiver.test(name)
            %
            % INPUTS:
            %   name:       String, Name of the specific tests to run. If
            %               no name is specified, all tests are run.
            %
            %   results:    TestResult, Array of test results indicating
            %               the success or failure of each test along with
            %               diagnostic information

            tests = ImageQuiverTest();
            results = tests.run(varargin{:});
        end
    end

    methods (Static, Hidden)
        function dance(id)
            % dance - Super secret undocumented function

            if ~exist('id', 'var')
                path = fullfile(matlabroot, 'toolbox', 'matlab', ...
                                'icons', 'matlabicon.gif');
                [im, map] = imread(path);
                alpha = im == im(1);
                img = ind2rgb(im, map);
                img(repmat(alpha, [1 1 3])) = NaN;
            else
                BASE = 'https://api.stackexchange.com/2.2';
                URL = sprintf('%s/users/%d', BASE, id);

                try
                    data = webread(URL, 'site', 'stackoverflow');
                    img = data.items.profile_image;
                catch
                    S = urlread(URL, 'get', {'site', 'stackoverflow'});
                    img = regexp(S, '(?<="profile_image":").*(?=")', 'match');
                end
            end

            fig = figure();
            hax = axes('Parent', fig);
            axis(hax, 'equal')

            % Plot a full circle
            t = linspace(0, 2*pi, 100);
            plot(cos(t) * 3 + 5, sin(t) * 3 + 5, 'Parent', hax);

            hold(hax, 'on')

            t = linspace(0, 2*pi, 13);
            dX = cos(t(1:end-1));
            dY = sin(t(1:end-1));
            X = (3 * dX) + 5;
            Y = (3 * dY) + 5;

            plot(X, Y, 'o', 'MarkerFaceColor', 'w', 'Parent', hax);

            him = imagesc(rand(9));
            uistack(him, 'bottom');

            axis(hax, 'equal');
            axis(hax, 'off');
            colormap(fig, 'gray');
            set(hax, 'clim', [-4 4]);

            h = ImageQuiver(img, X, Y, dX, dY, 1, 'Parent', hax);

            for k = 1:numel(dX)
                set(h, 'UData', circshift(dX, [0 k]), ...
                       'VData', circshift(dY, [0 -k]))
                drawnow
            end

            mag = sin(linspace(0, pi, numel(dX) + 1)) * 1.5;
            mag(end) = [];

            for k = 1:numel(dX)
                set(h, 'UData', dX .* mag(k), 'VData', dY .* mag(k))
                drawnow
            end

            mag = cat(2, linspace(1, 1.5, 5), ...
                         linspace(1.5, 0.5, 10), ...
                         linspace(0.5, 1, 5));

            for k = 1:numel(dX)
                set(h, 'UData', dX .* mag(k), 'VData', dY .* mag(k))
                drawnow
            end

            angles = linspace(0, 2*pi, 25);
            for k = 1:numel(angles)
                set(h, 'UData', dX * cos(angles(k)) - dY * sin(angles(k)), ...
                       'VData', dX * sin(angles(k)) + dY * cos(angles(k)))
                drawnow
            end
        end
    end
end
