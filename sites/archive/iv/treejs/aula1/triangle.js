


const renderTriangle = () => {

    var geometry = new THREE.BufferGeometry();
    var hiddenTriangle = new THREE.BufferGeometry();
    const hiddenTriangleVertices = new Float32Array([
        0.15, -0.95, 0.0,
        0.90, -0.7, 0.0,
        0.65, 0.10, 0.0
    ]);
    const vertices = new Float32Array([
        0.0, 0.0, 0.0,
        0.5, 0.75, 0.0,
        1.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        -0.35, -1.0, 0.0,
        -0.7, 0.25, 0.0,
        -0.2, 0.15, 0.0,
        0.35, 0.65, 0.0,
        -0.85, 0.9, 0.0,
        0.15, -0.95, 0.0,
        0.90, -0.7, 0.0,
        0.65, 0.10, 0.0
    ]);
    geometry.setAttribute('position', new THREE.BufferAttribute(vertices, 3));
    hiddenTriangle.setAttribute('position', new THREE.BufferAttribute(hiddenTriangleVertices, 3));
    var colors = new Uint8Array([
        255, 0, 255,
        255, 0, 255,
        255, 0, 255,
        255, 255, 0,
        255, 255, 0,
        255, 255, 0,
        255, 0, 0,
        0, 255, 0,
        0, 0, 255,
        0, 0, 0,
        0, 0, 0,
        0, 0, 0
    ]);
    geometry.setAttribute('color', new THREE.BufferAttribute(colors, 3, true));
    const geometryMaterial = new THREE.MeshBasicMaterial({ vertexColors: THREE.VertexColors, side: THREE.DoubleSide });
    const outlineMaterial1 = new THREE.MeshBasicMaterial({ color: "white", wireframe: true });
    const triangle = new THREE.Mesh(geometry, geometryMaterial);
    const triangleoOutline = new THREE.Mesh(hiddenTriangle, outlineMaterial1);

    const scene = new THREE.Scene();
    const trianglewin = document.getElementById("triangleWin")
    const camera = new THREE.PerspectiveCamera(75, 400 / 300, 0.1, 400);
    const renderer = new THREE.WebGLRenderer();
    renderer.setSize(400, 300);

    trianglewin.appendChild(renderer.domElement);
    scene.add(triangle);
    scene.add(triangleoOutline);
    camera.position.z = 5;
    const render = () => {
        requestAnimationFrame(render);
        renderer.render(scene, camera)
    }
    render();


}





renderTriangle()




