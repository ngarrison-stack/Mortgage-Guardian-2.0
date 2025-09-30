const AWS = require('aws-sdk');

const s3 = new AWS.S3();
const dynamodb = new AWS.DynamoDB.DocumentClient();

const DOCUMENT_BUCKET = process.env.DOCUMENT_BUCKET;
const DOCUMENT_TABLE = process.env.DOCUMENT_TABLE;

exports.handler = async (event) => {
    console.log('Document Storage Handler - Event:', JSON.stringify(event, null, 2));

    const headers = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key',
        'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
    };

    // Handle preflight OPTIONS requests
    if (event.httpMethod === 'OPTIONS') {
        return {
            statusCode: 200,
            headers,
            body: ''
        };
    }

    try {
        const path = event.path;
        const method = event.httpMethod;

        switch (method) {
            case 'POST':
                if (path === '/v1/documents/upload') {
                    return await uploadDocument(event, headers);
                }
                break;

            case 'GET':
                if (path === '/v1/documents') {
                    return await getDocuments(event, headers);
                } else if (path.startsWith('/v1/documents/')) {
                    const documentId = path.split('/').pop();
                    return await getDocument(documentId, headers);
                }
                break;

            case 'DELETE':
                if (path.startsWith('/v1/documents/')) {
                    const documentId = path.split('/').pop();
                    return await deleteDocument(documentId, headers);
                }
                break;

            default:
                return {
                    statusCode: 405,
                    headers,
                    body: JSON.stringify({ error: 'Method not allowed' })
                };
        }

        return {
            statusCode: 404,
            headers,
            body: JSON.stringify({ error: 'Not found' })
        };

    } catch (error) {
        console.error('Error:', error);
        return {
            statusCode: 500,
            headers,
            body: JSON.stringify({
                error: 'Internal server error',
                message: error.message
            })
        };
    }
};

async function uploadDocument(event, headers) {
    try {
        const body = JSON.parse(event.body);
        const { documentId, userId, fileName, documentType, content, analysisResults, metadata } = body;

        if (!documentId || !userId || !fileName || !content) {
            return {
                statusCode: 400,
                headers,
                body: JSON.stringify({
                    error: 'Missing required fields',
                    required: ['documentId', 'userId', 'fileName', 'content']
                })
            };
        }

        // Upload document content to S3
        const s3Key = `documents/${userId}/${documentId}`;
        await s3.putObject({
            Bucket: DOCUMENT_BUCKET,
            Key: s3Key,
            Body: content,
            ServerSideEncryption: 'AES256',
            ContentType: 'text/plain',
            Metadata: {
                'user-id': userId,
                'document-type': documentType,
                'file-name': fileName
            }
        }).promise();

        // Store metadata in DynamoDB
        const now = new Date().toISOString();
        const ttl = Math.floor(Date.now() / 1000) + (30 * 24 * 60 * 60); // 30 days from now

        await dynamodb.put({
            TableName: DOCUMENT_TABLE,
            Item: {
                userId,
                documentId,
                fileName,
                documentType,
                uploadDate: now,
                fileSize: metadata?.fileSize || content.length,
                s3Key,
                analysisResults: analysisResults || '[]',
                isEncrypted: metadata?.isEncrypted || true,
                ttl: ttl, // Auto-delete after 30 days
                metadata: metadata || {}
            }
        }).promise();

        console.log(`Document uploaded successfully: ${documentId}`);

        return {
            statusCode: 200,
            headers,
            body: JSON.stringify({
                success: true,
                documentId,
                message: 'Document uploaded successfully'
            })
        };

    } catch (error) {
        console.error('Upload error:', error);
        return {
            statusCode: 500,
            headers,
            body: JSON.stringify({
                error: 'Upload failed',
                message: error.message
            })
        };
    }
}

async function getDocuments(event, headers) {
    try {
        const userId = event.queryStringParameters?.userId;

        if (!userId) {
            return {
                statusCode: 400,
                headers,
                body: JSON.stringify({ error: 'userId parameter is required' })
            };
        }

        // Query DynamoDB for user's documents
        const result = await dynamodb.query({
            TableName: DOCUMENT_TABLE,
            KeyConditionExpression: 'userId = :userId',
            ExpressionAttributeValues: {
                ':userId': userId
            },
            ScanIndexForward: false // Sort by newest first
        }).promise();

        const documents = result.Items.map(item => ({
            documentId: item.documentId,
            userId: item.userId,
            fileName: item.fileName,
            documentType: item.documentType,
            uploadDate: item.uploadDate,
            fileSize: item.fileSize,
            analysisResults: item.analysisResults,
            isEncrypted: item.isEncrypted
        }));

        return {
            statusCode: 200,
            headers,
            body: JSON.stringify({
                documents,
                count: documents.length
            })
        };

    } catch (error) {
        console.error('Get documents error:', error);
        return {
            statusCode: 500,
            headers,
            body: JSON.stringify({
                error: 'Failed to retrieve documents',
                message: error.message
            })
        };
    }
}

async function getDocument(documentId, headers) {
    try {
        // Get document metadata from DynamoDB
        const result = await dynamodb.scan({
            TableName: DOCUMENT_TABLE,
            FilterExpression: 'documentId = :documentId',
            ExpressionAttributeValues: {
                ':documentId': documentId
            }
        }).promise();

        if (result.Items.length === 0) {
            return {
                statusCode: 404,
                headers,
                body: JSON.stringify({ error: 'Document not found' })
            };
        }

        const docMetadata = result.Items[0];

        // Get document content from S3
        const s3Object = await s3.getObject({
            Bucket: DOCUMENT_BUCKET,
            Key: docMetadata.s3Key
        }).promise();

        const content = s3Object.Body.toString();

        return {
            statusCode: 200,
            headers,
            body: JSON.stringify({
                documentId: docMetadata.documentId,
                fileName: docMetadata.fileName,
                documentType: docMetadata.documentType,
                content: content,
                uploadDate: docMetadata.uploadDate,
                analysisResults: docMetadata.analysisResults
            })
        };

    } catch (error) {
        console.error('Get document error:', error);
        return {
            statusCode: 500,
            headers,
            body: JSON.stringify({
                error: 'Failed to retrieve document',
                message: error.message
            })
        };
    }
}

async function deleteDocument(documentId, headers) {
    try {
        // Get document metadata to find S3 key
        const result = await dynamodb.scan({
            TableName: DOCUMENT_TABLE,
            FilterExpression: 'documentId = :documentId',
            ExpressionAttributeValues: {
                ':documentId': documentId
            }
        }).promise();

        if (result.Items.length === 0) {
            return {
                statusCode: 404,
                headers,
                body: JSON.stringify({ error: 'Document not found' })
            };
        }

        const docMetadata = result.Items[0];

        // Delete from S3
        await s3.deleteObject({
            Bucket: DOCUMENT_BUCKET,
            Key: docMetadata.s3Key
        }).promise();

        // Delete from DynamoDB
        await dynamodb.delete({
            TableName: DOCUMENT_TABLE,
            Key: {
                userId: docMetadata.userId,
                documentId: documentId
            }
        }).promise();

        console.log(`Document deleted successfully: ${documentId}`);

        return {
            statusCode: 200,
            headers,
            body: JSON.stringify({
                success: true,
                message: 'Document deleted successfully'
            })
        };

    } catch (error) {
        console.error('Delete document error:', error);
        return {
            statusCode: 500,
            headers,
            body: JSON.stringify({
                error: 'Failed to delete document',
                message: error.message
            })
        };
    }
}