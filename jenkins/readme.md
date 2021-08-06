## Plugins

1. Log into jenkins. Go to ```Manage jenkins``` > ```Manage Plugins``` > ```Installed``` tab. Make sure ```Docker Plugin```,  ```Docker Pipeline```, ```Kubernetes Plugin```, ```Kubernetes CLI Plugin``` are installed

2. Go to ```Manage jenkins``` > ```Manage Credentials``` > ```Stores scoped to Jenkins``` > ```Global Credentials```. Add following type of credentials (use other names if required),

```
docker-registry-cred - Username with password
gitlab-credentials - Username with password
cluster-token - Secret file (cluster kubeconfig to deploy directly to cluster)
jenkins-sa-kubernetes - Secret text (cluster serviceaccount token for jenkins to deploy jenkins-jnlp workers in kubernetes)
```

3. If you are going to use docker related commands, assuming you are using DinD container with jenkins, make sure ```${jenkins_home}/certs/client``` and ```/etc/docker/certs.d/your_registry:port``` folders and certificates exist. ```/etc/docker/certs.d/your_registry:port``` contents should look like below,

```
ca.crt
client.cert
client.key
```

4. If you are going to use ```Kubernetes CLI Plugin``` in pipeline, ```cluster-token``` credential is must. Add following variables in pipeline or as type of credentials in project or global scope (use other names if required), 

Sample pipeline

```
timestamps {
    node() {
        def sourceDeployDirectory = 'YOUR_DEPLOY_MANIFEST_DIRECTORY';
        def k8sNamespace = 'YOUR_K8S_NAMESPACE';
        def k8sContextName = 'YOUR_CLUSTER_CONTEXT'; //see kubeconfig
        def k8sClusterName = 'YOUR_CLUSTER_NAME'; //see kubeconfig
        def k8sClusterAPI = 'https://YOUR_IP:PORT'; //Your cluster api server ip and port
        def k8sClusterToken = 'cluster-token'; //Your cluster kubeconfig file as secret file credentials
        
        try {

            stage ('Deploy') {
                withKubeConfig([credentialsId: "${k8sClusterToken}",
                                serverUrl: "${k8sClusterAPI}",
                                contextName: "${k8sContextName}",
                                clusterName: "${k8sClusterName}",
                                namespace: "${k8sNamespace}"
                                ]) {
                    sh """
                        kubectl apply -f ${sourceDeployDirectory}/
                    """
                }
            }
        } catch (e) {
            // If there was an exception thrown, the build failed
            echo 'Err: Incremental Build failed with Error: ' + e.toString();
            currentBuild.result = "FAILED";
            throw e
        } finally {
            // Success or failure, always send notifications
            // notifyBuild(currentBuild.result)
        }
    }
}
```

5. Configure Node and Cloud. Deploy jenkins executor worker node as pods in kubernetes with jenkins/jnlp-slave images (#TODO)