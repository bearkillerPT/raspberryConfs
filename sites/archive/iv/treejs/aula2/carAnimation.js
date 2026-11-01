


const renderCarAnimation = () => {
    const radiusInput = document.getElementById("radiusInput")
    const speedInput = document.getElementById("speedInput")
    let radius =Number(radiusInput.value)
    let speed = Number(speedInput.value)

    radiusInput.addEventListener('input',(e)=>{radius=Number(radiusInput.value)})
    speedInput.addEventListener('input',(e)=>{speed = Number(speedInput.value)})
    const cubeGeometry = new THREE.BoxGeometry(2, 1, 4);
    const wheelGeometry = new THREE.CylinderGeometry(0.5, 0.5, 0.2, 10, 10);
    const axisGeometry = new THREE.CylinderGeometry(0.1, 0.1, 1, 10, 10);
    const wheelMaterial = new THREE.MeshPhongMaterial({
        color: '#aa412f',
        specular: '#a9fcff',
        shininess: 100,
        opacity: 0.8
    });
    const xAxisMaterial = new THREE.MeshPhongMaterial({
        color: '#0000FF',
        specular: '#a9fcff',
        shininess: 100,
        opacity: 0.8
    });
    const yAxisMaterial = new THREE.MeshPhongMaterial({
        color: '#FF0000',
        specular: '#a9fcff',
        shininess: 100,
        opacity: 0.8
    });
    const zAxisMaterial = new THREE.MeshPhongMaterial({
        color: '#00FF00',
        specular: '#a9fcff',
        shininess: 100,
        opacity: 0.8
    });
    const boxMaterial = new THREE.MeshPhongMaterial({
        color: '#6ac5e6',
        specular: '#a9fcff',
        shininess: 100,
        opacity: 0.7,
        transparent: true
    });
    const sphere1 = new THREE.Mesh(wheelGeometry, wheelMaterial).rotateZ(Math.PI / 2);
    const sphere2 = new THREE.Mesh(wheelGeometry, wheelMaterial).rotateZ(Math.PI / 2);
    const sphere3 = new THREE.Mesh(wheelGeometry, wheelMaterial).rotateZ(Math.PI / 2);
    const sphere4 = new THREE.Mesh(wheelGeometry, wheelMaterial).rotateZ(Math.PI / 2);
    const cube = new THREE.Mesh(cubeGeometry, boxMaterial);
    const xAxis = new THREE.Mesh(axisGeometry, xAxisMaterial);
    const yAxis = new THREE.Mesh(axisGeometry, yAxisMaterial);
    const zAxis = new THREE.Mesh(axisGeometry, zAxisMaterial);
    xAxis.position.set(0, 0, -0.5)
    yAxis.position.set(-0.5, 0, 0)
    zAxis.position.set(0, 0.5, 0)
    const scene = new THREE.Scene();
    const carwin = document.getElementById("carAnimationWin")
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
    const axis = new THREE.Object3D()
    car.add(cube)
    car.add(sphere1)
    car.add(sphere2)
    car.add(sphere3)
    car.add(sphere4)
    axis.add(xAxis.rotateX(Math.PI / 2))
    axis.add(yAxis.rotateZ(Math.PI / 2))
    axis.add(zAxis)

    const alight = new THREE.AmbientLight(0xffffff);
    scene.add(alight);
    const directionalLight = new THREE.DirectionalLight(0xffffff, 1);
    directionalLight.position.set(0, 5, 0)
    scene.add(directionalLight)
    scene.add(car)
    scene.add(axis)
    scene.add(camera)
    const controls = new THREE.OrbitControls(camera, renderer.domElement);
    camera.position.set(3, 2, -4)
    var state = 0
    const render = () => {
        requestAnimationFrame(render);
        renderer.render(scene, camera);
        controls.update()
        if(state == 0) {
            car.position.z = (car.position.z + speed)
            if (car.position.z > radius) {
    
                state = 1
                car.rotateY(Math.PI / 2)
    
            }
        }
        else if(state == 1) {
            car.position.x = (car.position.x - speed)
            if (car.position.x < -radius) {
                state = 2
                car.rotateY(Math.PI / 2)
            }
        }
        else if(state == 2) {
            car.position.z = (car.position.z - speed)
            if (car.position.z < -radius) {
                state = 3
                car.rotateY(Math.PI / 2)
            }
        }
        else if(state == 3) {
            car.position.x = (car.position.x + speed)
            if (car.position.x > radius) {
                state = 0
                car.rotateY(Math.PI / 2)
            }
        }
    }
    render();


}





renderCarAnimation()




