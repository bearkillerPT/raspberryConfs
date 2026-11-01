


const renderCube = () => {
    const rotate = (cube) => {
        cube.rotation.x += 0.01;
        cube.rotation.y += 0.01;
    }
    const cubeGeometry = new THREE.BoxGeometry(2, 2, 1);
    const geometry = new THREE.SphereGeometry(1, 10, 10);
    const material1 = new THREE.MeshPhongMaterial({
        color: '#006063',
        specular: '#a9fcff',
        shininess: 100,
        flatShading: true
    });
    const material2 = new THREE.MeshPhongMaterial({
        color: '#006063',
        specular: '#a9fcff',
        shininess: 100,
        flatShading: false
    });
    const emeraldMaterial = new THREE.MeshPhongMaterial({
        shading: THREE.SmoothShading
    });
    const glassMaterial = new THREE.MeshPhongMaterial( { 
        color: 0x222222, 
        specular: 0xFFFFFF,
        shininess: 100, 
        opacity: 0.3, 
        transparent: true 
        } )
    emeraldMaterial.color = new THREE.Color(0.07568, 0.61424, 0.07568);
    emeraldMaterial.specular = new THREE.Color(0.633, 0.7278, 0.633);
    emeraldMaterial.shininess = 0.6 * 256;
    const cube1 = new THREE.Mesh(cubeGeometry , glassMaterial);
    const sphere1 = new THREE.Mesh(geometry, material1);
    const sphere2 = new THREE.Mesh(geometry, material2);
    const emerald = new THREE.Mesh(geometry, emeraldMaterial);
    const cube2 = new THREE.Mesh(cubeGeometry , glassMaterial);
    cube1.position.x = -2.5
    sphere1.position.x = -2.5
    emerald.position.x = 0
    sphere2.position.x = 2.5
    cube2.position.x = 2.5

    const scene = new THREE.Scene();
    const spherewin = document.getElementById("sphereWin")
    const camera = new THREE.PerspectiveCamera(75, 400 / 300, 0.01, 100);
    const renderer = new THREE.WebGLRenderer();
    renderer.setSize(400, 300);

    spherewin.appendChild(renderer.domElement);
    const directionalLight = new THREE.DirectionalLight(0xffffff, 1);
    directionalLight.position.set(0, 5, 0)
    const alight = new THREE.AmbientLight(0xffffff);
    scene.add(alight);
    scene.add(directionalLight);
    scene.add(emerald);
    scene.add(cube1);
    scene.add(cube2);
    scene.add(sphere1);
    scene.add(sphere2);
    scene.add(camera)
    camera.position.z = 5;
    const render = () => {
        requestAnimationFrame(render);
        rotate(sphere1)
        rotate(sphere2)
        renderer.render(scene, camera);
    }
    render();


}





renderCube()




