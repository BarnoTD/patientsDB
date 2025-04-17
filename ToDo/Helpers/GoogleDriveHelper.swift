import GoogleAPIClientForREST_Drive
import GoogleSignIn

/// A helper class to perform CRUD operations on Google Drive using the Google API Client Library for REST.
class GoogleDriveHelper {
    // The service object for interacting with Google Drive API
    private let service: GTLRDriveService
    
    /// Initializes the helper with a signed-in Google user.
    /// - Parameter user: The `GIDGoogleUser` object from Google Sign-In.
    init(user: GIDGoogleUser) {
        self.service = GTLRDriveService()
        // Set the authorizer using the user's authentication
        self.service.authorizer = user.fetcherAuthorizer
    }
    
    // MARK: - Read Operations
    
    /// Lists files in the specified folder or in the root if no folder is specified.
    /// - Parameters:
    ///   - folderId: The ID of the folder to list files from. If nil, lists files in the root.
    ///   - completion: A closure called with an array of files or an error.
    func listFiles(inFolder folderId: String? = nil, completion: @escaping ([GTLRDrive_File]?, Error?) -> Void) {
        let query = GTLRDriveQuery_FilesList.query()
        query.spaces = "appDataFolder"
        if let folderId = folderId {
            // Filter files to those within the specified folder
            query.q = "'\(folderId)' in parents and trashed=false"
        }
        service.executeQuery(query) { (ticket, result, error) in
            DispatchQueue.main.async {
                if let error = error {
                    completion(nil, error)
                    return
                }
                if let fileList = result as? GTLRDrive_FileList {
                    completion(fileList.files, nil)
                } else {
                    completion(nil, nil)
                }
            }
        }
    }
    
    // Fetch file metadata (name and MIME type and properties)
    func getFileMetadata(fileId: String, completion: @escaping (GTLRDrive_File?, Error?) -> Void) {
        let query = GTLRDriveQuery_FilesGet.query(withFileId: fileId)
        query.fields = "id,name,mimeType,properties" // Fetch only what we need
        service.executeQuery(query) { (ticket, result, error) in
            DispatchQueue.main.async {
                if let error = error {
                    completion(nil, error)
                    return
                }
                if let file = result as? GTLRDrive_File {
                    completion(file, nil)
                } else {
                    completion(nil, nil)
                }
            }
        }
    }
    
    
    /// Downloads the content of a file from Google Drive.
    /// - Parameters:
    ///   - fileId: The ID of the file to download.
    ///   - completion: A closure called with the file data or an error.
    func downloadFile(fileId: String, completion: @escaping (Data?, Error?) -> Void) {
        let query = GTLRDriveQuery_FilesGet.queryForMedia(withFileId: fileId)
        service.executeQuery(query) { (ticket, result, error) in
            DispatchQueue.main.async {
                if let error = error {
                    completion(nil, error)
                    return
                }
                if let data = (result as? GTLRDataObject)?.data {
                    completion(data, nil)
                } else {
                    completion(nil, nil)
                }
            }
        }
    }
    
    /// Queries files in Google Drive with various search criteria.
    /// - Parameters:
    ///   - query: The query string in Google Drive query format.
    ///   - folderId: Optional folder ID to search within a specific folder.
    ///   - orderBy: Optional string to specify sort order (e.g., "name", "modifiedTime desc").
    ///   - maxResults: Maximum number of files to return (default 100).
    ///   - completion: A closure called with an array of files or an error.
    func queryFiles(query: String, inFolder folderId: String? = nil, orderBy: String? = nil, maxResults: Int = 100, completion: @escaping ([GTLRDrive_File]?, Error?) -> Void) {
        let filesQuery = GTLRDriveQuery_FilesList.query()
        filesQuery.spaces = "appDataFolder"
        
        // Build the query string
        var queryString = query
        if let folderId = folderId {
            if !queryString.isEmpty {
                queryString += " and "
            }
            queryString += "'\(folderId)' in parents"
        }
        
        // Always exclude trashed files unless explicitly querying for them
        if !queryString.contains("trashed") {
            if !queryString.isEmpty {
                queryString += " and "
            }
            queryString += "trashed=false"
        }
        
        if !queryString.isEmpty {
            filesQuery.q = queryString
        }
        
        // Set ordering if specified
        if let orderBy = orderBy {
            filesQuery.orderBy = orderBy
        }
        
        // Set maximum results
        filesQuery.pageSize = maxResults
        
        service.executeQuery(filesQuery) { (ticket, result, error) in
            DispatchQueue.main.async {
                if let error = error {
                    completion(nil, error)
                    return
                }
                if let fileList = result as? GTLRDrive_FileList {
                    completion(fileList.files, nil)
                } else {
                    completion(nil, nil)
                }
            }
        }
    }
    
    // MARK: - Create Operations
    
    /// Uploads a file to Google Drive.
    /// - Parameters:
    ///   - data: The data of the file to upload.
    ///   - name: The name of the file.
    ///   - mimeType: The MIME type of the file (e.g., "text/plain", "image/jpeg").
    ///   - folderId: The ID of the folder to upload to. If nil, uploads to the root.
    ///   - completion: A closure called with the uploaded file metadata or an error.
    func uploadFile(data: Data, name: String, mimeType: String, toFolder folderId: String? = nil, properties: [String: String]? = nil, completion: @escaping (GTLRDrive_File?, Error?) -> Void) {
        let file = GTLRDrive_File()
        file.name = name
        if let properties = properties {
            let propertiesObject = GTLRDrive_File_Properties()
                    // Use KVC to set the properties
                    properties.forEach { (key, value) in
                        propertiesObject.setAdditionalProperty(value, forName: key)
                    }
            file.properties = propertiesObject
            }
        if let folderId = folderId {
            file.parents = [folderId] // Set the parent folder
        }
        let uploadParameters = GTLRUploadParameters(data: data, mimeType: mimeType)
        let query = GTLRDriveQuery_FilesCreate.query(withObject: file, uploadParameters: uploadParameters)
        service.executeQuery(query) { (ticket, result, error) in
            DispatchQueue.main.async {
                if let error = error {
                    completion(nil, error)
                    return
                }
                if let uploadedFile = result as? GTLRDrive_File {
                    completion(uploadedFile, nil)
                } else {
                    completion(nil, nil)
                }
            }
        }
    }
    
    /// Creates a new folder in Google Drive.
    /// - Parameters:
    ///   - name: The name of the folder.
    ///   - folderId: The ID of the parent folder. If nil, creates the folder in the root.
    ///   - completion: A closure called with the created folder metadata or an error.
    func createFolder(name: String, inFolder folderId: String? = nil, completion: @escaping (GTLRDrive_File?, Error?) -> Void) {
        let folder = GTLRDrive_File()
        folder.name = name
        folder.mimeType = "application/vnd.google-apps.folder" // MIME type for folders
        if let folderId = folderId {
            folder.parents = [folderId]
        }
        let query = GTLRDriveQuery_FilesCreate.query(withObject: folder, uploadParameters: nil)
        service.executeQuery(query) { (ticket, result, error) in
            DispatchQueue.main.async {
                if let error = error {
                    completion(nil, error)
                    return
                }
                if let createdFolder = result as? GTLRDrive_File {
                    completion(createdFolder, nil)
                } else {
                    completion(nil, nil)
                }
            }
        }
    }
    
    // MARK: - Update Operations
    
    /// Updates the content of a file in Google Drive.
    /// - Parameters:
    ///   - fileId: The ID of the file to update.
    ///   - data: The new content of the file.
    ///   - mimeType: The MIME type of the new content.
    ///   - completion: A closure called with the updated file metadata or an error.
    func updateFile(fileId: String, data: Data, mimeType: String, properties: [String: String]? = nil, completion: @escaping (GTLRDrive_File?, Error?) -> Void) {
        let file = GTLRDrive_File()
        if let properties = properties {
            let propertiesObject = GTLRDrive_File_Properties()
                    // Use KVC to set the properties
                    properties.forEach { (key, value) in
                        propertiesObject.setAdditionalProperty(value, forName: key)
                    }
            file.properties = propertiesObject
            }
        let uploadParameters = GTLRUploadParameters(data: data, mimeType: mimeType)
        
        let query = GTLRDriveQuery_FilesUpdate.query(withObject: file, fileId: fileId, uploadParameters: uploadParameters)
        service.executeQuery(query) { (ticket, result, error) in
            DispatchQueue.main.async {
                if let error = error {
                    completion(nil, error)
                    return
                }
                if let updatedFile = result as? GTLRDrive_File {
                    completion(updatedFile, nil)
                } else {
                    completion(nil, nil)
                }
            }
        }
    }
    
    /// Renames a file in Google Drive.
    /// - Parameters:
    ///   - fileId: The ID of the file to rename.
    ///   - newName: The new name for the file.
    ///   - completion: A closure called with the updated file metadata or an error.
    func renameFile(fileId: String, newName: String, completion: @escaping (GTLRDrive_File?, Error?) -> Void) {
        let file = GTLRDrive_File()
        file.name = newName
        let query = GTLRDriveQuery_FilesUpdate.query(withObject: file, fileId: fileId, uploadParameters: nil)
        service.executeQuery(query) { (ticket, result, error) in
            DispatchQueue.main.async {
                if let error = error {
                    completion(nil, error)
                    return
                }
                if let updatedFile = result as? GTLRDrive_File {
                    completion(updatedFile, nil)
                } else {
                    completion(nil, nil)
                }
            }
        }
    }
    
    // MARK: - Delete Operations
    
    /// Deletes a file from Google Drive.
    /// - Parameters:
    ///   - fileId: The ID of the file to delete.
    ///   - completion: A closure called with an error if the deletion fails.
    func deleteFile(fileId: String, completion: @escaping (Error?) -> Void) {
        let query = GTLRDriveQuery_FilesDelete.query(withFileId: fileId)
        service.executeQuery(query) { (ticket, result, error) in
            DispatchQueue.main.async {
                completion(error)
            }
        }
    }
}
