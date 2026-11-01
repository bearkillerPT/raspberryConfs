


const renderOrthoCube = () => {
    console.log("here")
    const rotate = (cube) => {
        cube.rotation.x += 0.01;
        cube.rotation.y += 0.01;
    }
    const geometry = new THREE.BoxGeometry(1, 1, 1);
    const material = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
    const outlineMaterial = new THREE.MeshBasicMaterial({ color: "white", wireframe: true });
    const cube = new THREE.Mesh(geometry, material);
    const cubeOutline = new THREE.Mesh(geometry, outlineMaterial);
    const scene = new THREE.Scene();
    const cubewin = document.getElementById("cubeWinOrtho")
    const camera = new THREE.OrthographicCamera(-3, 3, 3*300/400, -3*300/400, 1, 1000);
    const renderer = new THREE.WebGLRenderer();
    renderer.setSize(400, 300);
    camera.position.x = 0;
    camera.position.y = 0;
    camera.position.z = 100;
    cubewin.appendChild(renderer.domElement);
    scene.add(cube);
    scene.add(cubeOutline);
    const controls = new THREE.OrbitControls(camera, renderer.domElement);
    const render = () => {
        requestAnimationFrame(render);
        //rotate(cube)
        //rotate(cubeOutline)
        renderer.render(scene, camera);
        controls.update()
    }
    render();


}





renderOrthoCube()




