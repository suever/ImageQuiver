classdef ImageQuiverTest < matlab.unittest.TestCase
    % ImageQuiverTest - Unit tests for the ImageQuiver class
    %
    % USAGE:
    %   tests = ImageQuiverTest();
    %   results = tests.run(name);
    %   results = ImageQuiver.test(name);
    %
    % INPUTS:
    %   name:       String, Name of the unit test(s) to be run
    %
    % OUTPUTS:
    %   results:    TestResult, An array of objects (one per test) that
    %               provide information on test completion status.

    % Copyright (c) <2016> Jonathan Suever (suever@gmail.com)
    % All rights reserved
    %
    % This software is licensed under the 3-clause BSD license.

    methods (Test)
        %--- Constructor Tests ---%
        function vanillaConstructor(testCase)
            % Test the most basic of inputs
            hax = testCase.axes();
            q = ImageQuiver(1, 1, 1, 1, 1);

            % Assert that it is a scalar ImageQuiver instance
            testCase.assertSize(q, [1 1]);
            testCase.assertClass(q, 'ImageQuiver');

            % Test implicit parent
            testCase.assertEqual(hax, get(q, 'Parent'));

            % Ensure there is one child in hax
            kids = get(hax, 'Children');
            testCase.assertSize(kids, [1 1]);
            testCase.assertTrue(ishghandle(kids, 'hggroup'));

            % Ensure that there is one surf object
            surfs = findall(hax, 'type', 'surf');
            testCase.assertSize(surfs, [1 1]);
        end

        function testExplicitParent(testCase)
            % Specify the parent in the constructor
            hax = testCase.axes();
            dummyax = testCase.axes();

            testCase.verifyEqual(dummyax, gca);

            % Explicit parent WITH scale
            q = ImageQuiver(1,1,1,1,1,1, 'Parent', hax);
            testCase.assertEqual(hax, get(q, 'Parent'))

            % Explicit parent WITHOUT scale
            q = ImageQuiver(1,1,1,1,1, 'Parent', hax);
            testCase.assertEqual(hax, get(q, 'Parent'))
        end

        function testDataDimensions(testCase)
            % Ensure that the proper data is assigned in the right way
            hax = testCase.axes();

            % Loop through a range of dimensions for each input
            dims = [1:4; 1:2:7].';

            for k = 1:size(dims, 1)
                shape = dims(1,:);
                x = rand(shape);
                y = rand(shape);
                u = rand(shape);
                v = rand(shape);
                c = rand(shape);
                q = ImageQuiver(c, x, y, u, v, 'Parent', hax);

                % Verify that all of the values were set appropriately
                testCase.assertEqual(get(q, 'XData'), x);
                testCase.assertEqual(get(q, 'YData'), y);
                testCase.assertEqual(get(q, 'UData'), u);
                testCase.assertEqual(get(q, 'VData'), v);
                testCase.assertEqual(get(q, 'CData'), c);

                % Now make sure that the correct number of surfaces exist
                surfaces = findall(hax, 'type', 'surf');
                testCase.assertNumElements(surfaces, numel(x));

                cla(hax);
            end
        end

        %--- Position Calculations ---%
        function testScaling(testCase)
            % Test that all positioning/scaling is correct
            hax = testCase.axes();

            q = ImageQuiver(1, 1, 1, 1, 1, 'Parent', hax);
            x = rand(10,1) - 0.5;
            y = rand(10,1) - 0.5;
            dx = rand(10,1) - 0.5;
            dy = rand(10,1) - 0.5;

            scales = (rand(10,1) - 0.5) * 10;

            S = findall(hax, 'Type', 'surf');

            for k = 1:numel(x)
                set(q, 'XData', x(k), 'YData', y(k), ...
                       'UData', dx(k), 'VData', dy(k), ...
                       'AutoScaleFactor', scales(k))

                % Now check that everything is how it should be
                centerx = x(k) + (scales(k) * 0.5 * dx(k));
                centery = y(k) + (scales(k) * 0.5 * dy(k));

                xdata = get(S, 'XData');
                ydata = get(S, 'YData');

                testCase.assertTrue(abs(mean(xdata(:)) - centerx) < 1e-12);
                testCase.assertTrue(abs(mean(ydata(:)) - centery) < 1e-12);
            end
        end

        %--- CData Behavior ---%
        function testFilePathCData(testCase)
            % Make sure we can pass a file path as CData
            hax = testCase.axes();

            % Test a valid file path
            img = fullfile(matlabroot, 'toolbox', 'matlab', 'icons', ...
                           'matlabicon.gif');
            func = @(p)ImageQuiver(p,1,1,1,1,'Parent', hax);
            testCase.assertWarningFree(@()func(img))

            % Test an invalid file path
            img = '_imgdoesntexist';
            testCase.verifyEqual(0, exist(img, 'file'));
            ID = 'MATLAB:imagesci:imread:fileDoesNotExist';
            testCase.assertError(@()func(img), ID);
        end

        function testNaNCData(testCase)
            % Pass NaN with the CData
            hax = testCase.axes();

            cdata = [NaN, 1; 2, NaN];
            alpha = ~isnan(cdata);

            % Construct our basic object
            q = ImageQuiver(cdata, 1, 1, 1, 1, 'Parent', hax);

            % Get surface handles
            surfaces = findall(hax, 'type', 'surf');

            % Ensure NaNs were correctly converted to alphadata
            adata = get(surfaces, 'AlphaData');
            testCase.assertEqual(double(alpha), adata);
            testCase.assertEmpty(get(q, 'AlphaData'));

            % Now set the AlphaData explicitly
            newalpha = 0.5;
            set(q, 'AlphaData', newalpha);

            % Now check the alpha data
            testCase.assertEqual(get(q, 'AlphaData'), newalpha);
            testCase.assertEqual(get(surfaces, 'AlphaData'), newalpha);
        end

        %--- Plot Update Behavior ---%
        function testSizeMismatchWarning(testCase)
            % Change data size to create mismatch
            hax = testCase.axes();
            q = ImageQuiver(1,1,1,1,1, 'Parent', hax);

            function res = surfvisibility()
                obj = findall(hax, 'type', 'surf');
                res = get(obj, 'Visible');
            end

            ID = 'ImageQuiver:DimensionWarning';

            % Warning should be shown and nothing displayed
            testCase.assertWarning(@()set(q, 'YData', [1 2]), ID);
            testCase.assertEqual(surfvisibility, 'off');

            % Warning should be shown and nothing displayed
            testCase.assertWarning(@()set(q, 'UData', [1 2]), ID);
            testCase.assertEqual(surfvisibility, 'off');

            % Warning should be shown and nothing displayed
            testCase.assertWarning(@()set(q, 'VData', [1 2]), ID);
            testCase.assertEqual(surfvisibility, 'off');

            % When we finally update the last param, there should be no
            % warnings and now two surfaces
            testCase.assertWarningFree(@()set(q, 'XData', [1 2]));
            testCase.assertEqual(surfvisibility, {'on'; 'on'});
        end

        function testSizeChangeViaSetMethod(testCase)
            % When using set(), no warnings should occur
            hax = testCase.axes();
            q = ImageQuiver(1,1,1,1,1, 'Parent', hax);

            func = @()set(q, 'XData', [1 2], ...
                             'YData', [1 2], ...
                             'UData', [1 2], ...
                             'VData', [1 2]);

            testCase.assertWarningFree(func);
        end

        %--- Object Cleanup/Deletion Tests ---%
        function testParentDeletion(testCase)
            % Delete the parent axes and ensure object is also deleted
            hax = testCase.axes();
            q = ImageQuiver(1,1,1,1,1, 'Parent', hax);

            testCase.assertTrue(isvalid(q));
            delete(hax)

            testCase.assertFalse(isvalid(q));
        end

        function testDelete(testCase)
            % Make sure all graphics are removed when the object is deleted
            hax = testCase.axes();
            q = ImageQuiver(1,1,1,1,1, 'Parent', hax);

            % Get the handle to the parent hggroup
            group = findall(hax, 'type', 'hggroup');

            % Ensure graphics exist
            testCase.assertSize(group, [1 1]);
            testCase.assertTrue(ishghandle(group, 'hggroup'));

            % Delete with no warnings and check that graphics are gone
            testCase.assertWarningFree(@()delete(q));
            testCase.assertFalse(ishghandle(group, 'hggroup'));
            testCase.assertSize(findall(hax), [1 1]);
        end
    end

    % Helper methods
    methods
        function hax = axes(testCase, varargin)
            % axes - Creates an axes and registers teardown functions
            fig = figure('Visible', 'off');
            hax = axes(varargin{:}, 'Parent', fig);

            % Ensure that all figures/axes are deleted after tests
            testCase.addTeardown(@(varargin)delete(fig(isvalid(fig))));
        end
    end
end
