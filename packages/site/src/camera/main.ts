import "../site.css";
import "../styles/camera-page.css";

import {
  AmbientLight,
  Box3,
  Color,
  DirectionalLight,
  Group,
  HemisphereLight,
  LoadingManager,
  Mesh,
  MeshStandardMaterial,
  PerspectiveCamera,
  PCFSoftShadowMap,
  PlaneGeometry,
  Scene,
  ShadowMaterial,
  SRGBColorSpace,
  Vector3,
  WebGLRenderer,
} from "three";
import { OBJLoader } from "three/examples/jsm/loaders/OBJLoader.js";
import { MTLLoader } from "three/examples/jsm/loaders/MTLLoader.js";
import { OrbitControls } from "three/examples/jsm/controls/OrbitControls.js";

const PAPER = 0xf3f7f2;
const ACCENT = 0x277c68;

const viewport = document.getElementById("camera-viewport") as HTMLDivElement | null;
const canvas = document.getElementById("camera-canvas") as HTMLCanvasElement | null;
const statusEl = document.getElementById("camera-status");
const statusLabel = statusEl?.querySelector(".camera-status-label") as HTMLSpanElement | null;
const triCountEl = document.getElementById("camera-tri-count");
const boundsEl = document.getElementById("camera-bounds");

if (viewport && canvas) {
  mount(viewport, canvas);
}

function setStatus(state: "loading" | "ready" | "error", label: string) {
  if (!statusEl || !statusLabel) return;
  statusEl.dataset.state = state;
  statusLabel.textContent = label;
}

function mount(viewportEl: HTMLDivElement, canvasEl: HTMLCanvasElement) {
  const renderer = new WebGLRenderer({
    canvas: canvasEl,
    antialias: true,
    alpha: true,
    powerPreference: "high-performance",
  });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  renderer.outputColorSpace = SRGBColorSpace;
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = PCFSoftShadowMap;

  const scene = new Scene();
  scene.background = null;

  const camera = new PerspectiveCamera(34, 1, 0.1, 2000);
  camera.position.set(110, 70, 140);

  // Lighting — a paper-cream key + cool rim, for the site's palette.
  const hemi = new HemisphereLight(0xfcfdfb, 0xcfd9d1, 0.75);
  scene.add(hemi);

  const key = new DirectionalLight(0xfff7e8, 1.55);
  key.position.set(80, 160, 110);
  key.castShadow = true;
  key.shadow.mapSize.set(2048, 2048);
  const sh = key.shadow.camera;
  sh.near = 10;
  sh.far = 600;
  sh.left = -180;
  sh.right = 180;
  sh.top = 180;
  sh.bottom = -180;
  key.shadow.bias = -0.0005;
  key.shadow.radius = 6;
  scene.add(key);

  const rim = new DirectionalLight(new Color(ACCENT).lerp(new Color(0xffffff), 0.75), 0.55);
  rim.position.set(-140, 50, -120);
  scene.add(rim);

  const fill = new AmbientLight(0xffffff, 0.22);
  scene.add(fill);

  // Contact shadow plane.
  const shadowPlane = new Mesh(
    new PlaneGeometry(800, 800),
    new ShadowMaterial({ opacity: 0.28, color: 0x0c1311 }),
  );
  shadowPlane.rotation.x = -Math.PI / 2;
  shadowPlane.receiveShadow = true;
  scene.add(shadowPlane);

  // Model group (rotated to sit flat, centered, scaled later).
  const modelGroup = new Group();
  scene.add(modelGroup);

  // Controls.
  const controls = new OrbitControls(camera, canvasEl);
  controls.enableDamping = true;
  controls.dampingFactor = 0.075;
  controls.rotateSpeed = 0.75;
  controls.zoomSpeed = 0.8;
  controls.panSpeed = 0.7;
  controls.minDistance = 40;
  controls.maxDistance = 360;
  controls.maxPolarAngle = Math.PI / 2 - 0.05;
  controls.autoRotate = true;
  controls.autoRotateSpeed = 0.35;
  controls.target.set(0, 0, 0);
  controls.update();

  // Pause auto-rotate on interaction, resume after a beat.
  let autoRotateTimer: number | null = null;
  const pauseAutoRotate = () => {
    controls.autoRotate = false;
    if (autoRotateTimer !== null) window.clearTimeout(autoRotateTimer);
    autoRotateTimer = window.setTimeout(() => {
      controls.autoRotate = true;
    }, 3200);
  };
  ["pointerdown", "wheel", "touchstart"].forEach((evt) =>
    canvasEl.addEventListener(evt, pauseAutoRotate, { passive: true }),
  );

  // Reset on R.
  const homeCam = camera.position.clone();
  const homeTarget = controls.target.clone();
  window.addEventListener("keydown", (e) => {
    if (e.key === "r" || e.key === "R") {
      camera.position.copy(homeCam);
      controls.target.copy(homeTarget);
      controls.autoRotate = true;
      controls.update();
    }
  });

  // Sizing.
  const resize = () => {
    const rect = viewportEl.getBoundingClientRect();
    const w = Math.max(1, Math.floor(rect.width));
    const h = Math.max(1, Math.floor(rect.height));
    renderer.setSize(w, h, false);
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
  };
  const ro = new ResizeObserver(resize);
  ro.observe(viewportEl);
  resize();

  // Load the model (MTL then OBJ).
  setStatus("loading", "loading model…");

  const manager = new LoadingManager();
  manager.onError = (url) => {
    setStatus("error", `couldn't load ${url.split("/").pop()}`);
  };

  const mtlLoader = new MTLLoader(manager);
  mtlLoader.setPath("/models/");
  mtlLoader.load(
    "obj.mtl",
    (materials) => {
      materials.preload();
      const objLoader = new OBJLoader(manager);
      objLoader.setMaterials(materials);
      objLoader.setPath("/models/");
      objLoader.load(
        "tinker.obj",
        (obj) => {
          installModel(obj);
        },
        undefined,
        () => setStatus("error", "couldn't load tinker.obj"),
      );
    },
    undefined,
    () => {
      // Fall back to loading the OBJ without materials.
      const objLoader = new OBJLoader(manager);
      objLoader.setPath("/models/");
      objLoader.load(
        "tinker.obj",
        (obj) => installModel(obj),
        undefined,
        () => setStatus("error", "couldn't load tinker.obj"),
      );
    },
  );

  function installModel(root: Group) {
    // Re-skin all meshes with a tasteful paper material + soft accent tint
    // via vertex-height gradient (on a single-mesh OBJ, the standard
    // mesh-split accent trick doesn't fire).
    const skin = new MeshStandardMaterial({
      color: new Color(PAPER).convertSRGBToLinear(),
      metalness: 0.08,
      roughness: 0.62,
    });

    let triangles = 0;
    root.traverse((child) => {
      const mesh = child as Mesh;
      if (mesh.isMesh) {
        mesh.castShadow = true;
        mesh.receiveShadow = true;
        mesh.material = skin;
        const geom = mesh.geometry;
        const pos = geom.attributes.position;
        if (geom.index) triangles += geom.index.count / 3;
        else if (pos) triangles += pos.count / 3;
      }
    });

    // Compute bounds, recenter, scale to a comfortable size.
    const bbox = new Box3().setFromObject(root);
    const size = new Vector3();
    bbox.getSize(size);
    const center = new Vector3();
    bbox.getCenter(center);

    const TARGET = 80;
    const maxDim = Math.max(size.x, size.y, size.z) || 1;
    const s = TARGET / maxDim;
    root.scale.setScalar(s);
    root.position.sub(center.multiplyScalar(s));

    // Drop it on the shadow plane.
    const postBox = new Box3().setFromObject(root);
    const minY = postBox.min.y;
    root.position.y -= minY;
    shadowPlane.position.y = 0;

    // Slight yaw for a more "presentational" three-quarter read.
    root.rotation.y = -0.4;

    modelGroup.add(root);

    // Camera framing — center the part in frame with comfortable padding.
    const framingBox = new Box3().setFromObject(modelGroup);
    const fSize = new Vector3();
    framingBox.getSize(fSize);
    const fCenter = new Vector3();
    framingBox.getCenter(fCenter);
    const radius = Math.max(fSize.x, fSize.y, fSize.z) * 0.5;
    const dist = (radius / Math.sin((camera.fov * Math.PI) / 180 / 2)) * 1.4;
    camera.position.set(dist * 0.65, dist * 0.55, dist * 0.9);
    controls.target.copy(fCenter);
    homeCam.copy(camera.position);
    homeTarget.copy(controls.target);
    controls.update();

    if (triCountEl) triCountEl.textContent = `${triangles.toLocaleString()} tris`;
    if (boundsEl) {
      const ox = (size.x * s).toFixed(0);
      const oy = (size.y * s).toFixed(0);
      const oz = (size.z * s).toFixed(0);
      boundsEl.textContent = `${ox} × ${oy} × ${oz}`;
    }
    setStatus("ready", "ready · drag to orbit");
  }

  // Render loop with prefers-reduced-motion awareness.
  const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
  if (reducedMotion.matches) controls.autoRotate = false;
  reducedMotion.addEventListener("change", (e) => {
    controls.autoRotate = !e.matches;
  });

  let raf = 0;
  const render = () => {
    raf = requestAnimationFrame(render);
    controls.update();
    renderer.render(scene, camera);
  };
  render();

  // Hygiene.
  window.addEventListener("beforeunload", () => {
    cancelAnimationFrame(raf);
    ro.disconnect();
    renderer.dispose();
  });

}
