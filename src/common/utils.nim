from vmath import GVec2, GVec3, GVec4, GMat2, GMat3, GMat4

func flatten*[T](mat: GMat2[T]): seq[float32] =
    @[
        float32 mat[0,0], mat[0,1],
                mat[1,0], mat[1,1],
    ]

func flatten*[T](mat: GMat3[T]): seq[float32] =
    @[
        float32 mat[0,0], mat[0,1], mat[0,2],
                mat[1,0], mat[1,1], mat[1,2],
                mat[2,0], mat[2,1], mat[2,2],
    ]

func flatten*[T](mat: GMat4[T]): seq[float32] =
    @[
        float32 mat[0,0], mat[0,1], mat[0,2], mat[0,3],
                mat[1,0], mat[1,1], mat[1,2], mat[1,3],
                mat[2,0], mat[2,1], mat[2,2], mat[2,3],
                mat[3,0], mat[3,1], mat[3,2], mat[3,3],
    ]

func flatten*[T](v: GVec2[T]): seq[float32] = 
    @[
        float32 v[0], v[1]
    ]

func flatten*[T](v: GVec3[T]): seq[float32] = 
    @[
        float32 v[0], v[1], v[2]
    ]

func flatten*[T](v: GVec4[T]): seq[float32] = 
    @[
        float32 v[0], v[1], v[2], v[3]
    ]