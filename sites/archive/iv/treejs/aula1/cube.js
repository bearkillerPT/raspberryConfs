


const renderCube = () => {
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
    const cubewin = document.getElementById("cubeWin")
    const camera = new THREE.PerspectiveCamera(75, 400/300, 0.1, 400);
    const renderer = new THREE.WebGLRenderer();
    renderer.setSize(400, 300);
    
    cubewin.appendChild(renderer.domElement);
    scene.add(cube);
    scene.add(cubeOutline);
    camera.position.z = 5;
    const render = () => {
        requestAnimationFrame(render);
        rotate(cube)
        rotate(cubeOutline)
        renderer.render(scene, camera);
    }
    render();


}





renderCube()




