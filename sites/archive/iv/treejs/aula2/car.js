


const renderCar = () => {

    const cubeGeometry = new THREE.BoxGeometry(2, 1, 4);
    const sphereGeometry = new THREE.SphereGeometry(0.5, 10, 10);
    const sphereMaterial = new THREE.MeshPhongMaterial({
        color: '#aa412f',
        specular: '#a9fcff',
        shininess: 100
    });
    const boxMaterial = new THREE.MeshPhongMaterial({
        color: '#6ac5e6',
        specular: '#a9fcff',
        shininess: 100,
        opacity: 0.8, 
        transparent: true 
    });
    const sphere1 = new THREE.Mesh(sphereGeometry, sphereMaterial);
    const sphere2 = new THREE.Mesh(sphereGeometry, sphereMaterial);
    const sphere3 = new THREE.Mesh(sphereGeometry, sphereMaterial);
    const sphere4 = new THREE.Mesh(sphereGeometry, sphereMaterial);
    const cube = new THREE.Mesh(cubeGeometry, boxMaterial);
    const scene = new THREE.Scene();
    const carwin = document.getElementById("carWin")
    const camera = new THREE.PerspectiveCamera(75, 400 / 300, 0.01, 100);
    const renderer = new THREE.WebGLRenderer();
    renderer.setSize(400, 300);
    carwin.appendChild(renderer.domElement);
    cube.position.set(0, 0, 0)
    sphere1.position.set(-1, -0.5, 2)
    sphere2.position.set(-1, -0.5, -2)
    sphere3.position.set(1, -0.5, -2)
    sphere4.position.set(1, -0.5, 2)
    const car = new THREE.Object3D()
    car.add(cube)
    car.add(sphere1)
    car.add(sphere2)
    car.add(sphere3)
    car.add(sphere4)
    const alight = new THREE.AmbientLight(0xffffff);
    scene.add(alight);
    const directionalLight = new THREE.DirectionalLight(0xffffff, 1);
    directionalLight.position.set(0, 5, 0)
    scene.add(directionalLight)
    scene.add(car)
    scene.add(camera)
    const controls = new THREE.OrbitControls(camera, renderer.domElement);
    camera.position.set(5,0,0)
    const render = () => {
        requestAnimationFrame(render);
        renderer.render(scene, camera);
        controls.update()
    }
    render();


}





renderCar()




