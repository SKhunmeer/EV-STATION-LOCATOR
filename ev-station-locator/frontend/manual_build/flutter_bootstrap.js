window._flutter = window._flutter || {};
window._flutter.buildConfig = {
  "engineRevision": "81c9d830f74851283bd9a7b91324dfcb52f201fd",
  "useLocalCanvasKit": true,
  "builds": [
    {
      "compileTarget": "dart2js",
      "renderer": "canvaskit",
      "mainJsPath": "main.dart.js",
      "useLocalCanvasKit": true
    }
  ]
};
_flutter.loader.load({
  config: {
    renderer: "canvaskit",
    canvasKitBaseUrl: "canvaskit"
  },
  onEntrypointLoaded: async function(engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine({
      multiViewEnabled: false
    });
    await appRunner.runApp();
  }
});
