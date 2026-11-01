


const renderSphere = () => {
    const rotate = (sphere) => {
        sphere.rotation.x += 0.01;
        sphere.rotation.y += 0.01;
    }
    const x = 0, y = 0;

    const geometry = new THREE.SphereGeometry(100, 8, 8); 
    const material = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
    const outlineMaterial = new THREE.MeshBasicMaterial({ color: "white", wireframe: true });
    const sphere = new THREE.Mesh(geometry, material);
    const sphereOutline = new THREE.Mesh(geometry, outlineMaterial);
    const scene = new THREE.Scene();
    const spherewin = document.getElementById("sphereWin")
    const camera = new THREE.PerspectiveCamera(75, 400 / 300, 0.1, 400);
    const renderer = new THREE.WebGLRenderer();
    renderer.setSize(400, 300);

    spherewin.appendChild(renderer.domElement);
    scene.add(sphere);
    scene.add(sphereOutline);
    camera.position.z = 5;
    const render = () => {
        requestAnimationFrame(render);
        rotate(sphere)
        rotate(sphereOutline)
        renderer.render(scene, camera);
    }
    render();


}





renderSphere()




