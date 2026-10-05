# Most videos need the libav/bad/ugly GStreamer decoders.
{ pkgs, lib, gslapper }:
let
  gstPlugins = with pkgs.gst_all_1; [ gstreamer.out gst-plugins-base gst-plugins-good gst-plugins-bad gst-libav gst-plugins-ugly ];
in gslapper.overrideAttrs (_: {
  postFixup = ''
    wrapProgram $out/bin/gslapper \
      --prefix GST_PLUGIN_SYSTEM_PATH_1_0 : "${lib.makeSearchPath "lib/gstreamer-1.0" gstPlugins}"
  '';
})
