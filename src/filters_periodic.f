************************************************************************
*  Subroutine: Init_Filters                                            *
*                                                                      *
*  Function:   It is responsible for defining the left hand matrix and *
*              performing LDU decomposition on them.                   *
*                                                                      *
*  Written by Daniel J. Bodony (bodony@stanford.edu)                   *
************************************************************************
      Subroutine Init_Filters
      Include 'header'
      Include 'LES_header'

*  Locals
      Integer I, J, K, N
      Real*8  Work_x(Mx,Mx), Work_y(My,My), Work_z(Mz,Mz)

*  x- y- and z-filters non-periodic eighth order Pade scheme 
*
*  The nodes are sixth order accurate
*
*  beta * F(I-2) + alpha * F(I-1) + F(I) + 
*
*  beta * F(I+2) + alpha * F(I+1) 
*
*          [ f(I+3) + f(I-3) ]        [ f(I+2) + f(I-2) ]
*    = a3 --------------------- + a2 ---------------------
*                   2                          2 
*
*            [ f(I+1) + f(I-1) ]
*      + a1 --------------------- + a0 f(I)
*                     2 
*
*  where
*
*  alpha =   0.663204892041650 E-00
*   beta =   0.164867523042040 E-00
*    a0  =   0.25 * (2 + 3 * alpha)
*    a1  =   (1/16) * (9 + 16 * alpha + 10 * beta)
*    a2  =   0.25 * (alpha + 4 * beta)
*    a3  =   (1/16) * (6 * beta - 1)


      Do N = 1, LotX  ! (My * Mz)
        Do I = 1,Mx
          ldu_filt_x_A(N,I) = beta_filt4
          ldu_filt_x_B(N,I) = alpha_filt4
          ldu_filt_x_C(N,I) = 1.0D0
          ldu_filt_x_D(N,I) = alpha_filt4
          ldu_filt_x_E(N,I) = beta_filt4
        End Do
      End Do

      Do N = 1, LotY  ! (Mz * Mx)
        Do J = 1,My
          ldu_filt_y_A(N,J) = beta_filt4
          ldu_filt_y_B(N,J) = alpha_filt4
          ldu_filt_y_C(N,J) = 1.0D0
          ldu_filt_y_D(N,J) = alpha_filt4
          ldu_filt_y_E(N,J) = beta_filt4
        End Do
      End Do

      Do N = 1, LotZ  ! (Mx * My)
        Do K = 1,Mz
          ldu_filt_z_A(N,K) = beta_filt4
          ldu_filt_z_B(N,K) = alpha_filt4
          ldu_filt_z_C(N,K) = 1.0D0
          ldu_filt_z_D(N,K) = alpha_filt4
          ldu_filt_z_E(N,K) = beta_filt4
        End Do
      End Do

      Return

      End

************************************************************************
*  Subroutines: Compact_Filter                                         *
*                                                                      *
*  Function:    Filter the flow variable F in the x-, y-, and          *
*               z-directions using a high-wavenumber filter            *
*               (Compact_Filter)                                       *
*                                                                      *
*                                                                      *
*               Filtering in each coordinate direction is handled by   *
*               the routines Compact_Filter_X, Compact_Filter_Y, or    *
*               Compact_Filter_Z                                       *
*                                                                      *
************************************************************************
      Subroutine Compact_Filter(F, F0, N)
      Include 'header'
      Include 'LES_header'

*  Locals
      Integer L, N

*  Globals
      Real*8  F(My,Mz,Mx,N), F0(My,Mz,Mx,N)
      Real*8  F1(My,Mz,Mx,N),F2(My,Mz,Mx,N)

      Do L = 1, N

*  Filter in X, Y & Z
         Call Compact_Filter_X(F(1,1,1,L),  F0(1,1,1,L))
         Call Compact_Filter_Y(F0(1,1,1,L), F0(1,1,1,L))
         Call Compact_Filter_Z(F0(1,1,1,L), F0(1,1,1,L))
      End Do

      Return

      End


*********************************************************************
      Subroutine Compact_Filter_X(F, F0)

      Include 'header'
      Include 'LES_header'
      Include 'mpif.h'

      Real*8  F(My,Mz,Mx), F0(My,Mz,Mx)
      Real*8  FP(My,Mz,4), FN(My,Mz,4)
      Real*8  W(LotX, Mx), W2(My,Mz,Mx)
      Real*8  temp(My,Mz,4,2)
      Integer status_arr(MPI_STATUS_SIZE,4), ierr, req(4)
      
*  Locals
      Integer I, J, K, N

* Putting first 4 and last 4 data planes into temp arrays for sending
      temp(:,:,:,1) = F(:,:,1:4)
      temp(:,:,:,2) = F(:,:,Mx-3:Mx)

* Transferring data from neighbouring processors
      Call MPI_IRECV(FP(1,1,1),   My*Mz*4, MPI_REAL8,source_right_x,
     .               source_right_x,                                 ! Recv last 4 planes
     .               MPI_XYZ_COMM, req(1), ierr)

      Call MPI_IRECV(FN(1,1,1),   My*Mz*4, MPI_REAL8,source_left_x,
     .               source_left_x,                                  ! Recv first 4 planes
     .               MPI_XYZ_COMM, req(2), ierr)

      Call MPI_ISEND(temp(1,1,1,2), My*Mz*4, MPI_REAL8,dest_right_x,
     .               rank,                                           ! Send last 4 planes
     .               MPI_XYZ_COMM, req(3), ierr)

      Call MPI_ISEND(temp(1,1,1,1), My*Mz*4, MPI_REAL8,dest_left_x,
     .               rank,                                           ! Send first 4 planes
     .               MPI_XYZ_COMM, req(4), ierr)
      

* Compute interior in the meantime
      Do J = 1, My
        Do K = 1, Mz
          N =  (J-1) * Mz + K
          Do I = 5, Mx-4
            W(N,I) =     a4_filt4 * ( F(J,K,I+4) + F(J,K,I-4) )
     .                 + a3_filt4 * ( F(J,K,I+3) + F(J,K,I-3) )
     .                 + a2_filt4 * ( F(J,K,I+2) + F(J,K,I-2) )
     .                 + a1_filt4 * ( F(J,K,I+1) + F(J,K,I-1) )
     .                 + a0_filt4 *   F(J,K,I)
          End Do
        End Do
      End Do

*  Wait to recieve planes
      Call MPI_WAITALL(4, req, status_arr, ierr)

      Do J = 1, My
        Do K = 1, Mz

           N =  (J-1) * Mz + K

           W(N,1) =      a4_filt4 * ( F(J,K,5) + FP(J,K,1) )
     .                 + a3_filt4 * ( F(J,K,4) + FP(J,K,2) )
     .                 + a2_filt4 * ( F(J,K,3) + FP(J,K,3) )
     .                 + a1_filt4 * ( F(J,K,2) + FP(J,K,4) )
     .                 + a0_filt4 *   F(J,K,1)


           W(N,2) =      a4_filt4 * ( F(J,K,6) + FP(J,K,2) )
     .                 + a3_filt4 * ( F(J,K,5) + FP(J,K,3) )
     .                 + a2_filt4 * ( F(J,K,4) + FP(J,K,4) )
     .                 + a1_filt4 * ( F(J,K,3) + F(J,K,1) )
     .                 + a0_filt4 *   F(J,K,2)

           W(N,3) =      a4_filt4 * ( F(J,K,7) + FP(J,K,3) )
     .                 + a3_filt4 * ( F(J,K,6) + FP(J,K,4) )
     .                 + a2_filt4 * ( F(J,K,5) + F(J,K,1)  )
     .                 + a1_filt4 * ( F(J,K,4) + F(J,K,2)  )
     .                 + a0_filt4 *   F(J,K,3)

           W(N,4) =      a4_filt4 * ( F(J,K,8) + FP(J,K,4) )
     .                 + a3_filt4 * ( F(J,K,7) + F(J,K,1)  )
     .                 + a2_filt4 * ( F(J,K,6) + F(J,K,2)  )
     .                 + a1_filt4 * ( F(J,K,5) + F(J,K,3)  )
     .                 + a0_filt4 *   F(J,K,4)
        End Do
      End Do

      Do J = 1, My
        Do K = 1, Mz

          N =  (J-1) * Mz + K

          W(N,Mx-3) =    a4_filt4 * ( FN(J,K,1)   + F(J,K,Mx-7) )
     .                 + a3_filt4 * ( F(J,K,Mx)   + F(J,K,Mx-6) )
     .                 + a2_filt4 * ( F(J,K,Mx-1) + F(J,K,Mx-5) )
     .                 + a1_filt4 * ( F(J,K,Mx-2) + F(J,K,Mx-4) )
     .                 + a0_filt4 *   F(J,K,Mx-3)

          W(N,Mx-2) =    a4_filt4 * ( FN(J,K,2) + F(J,K,Mx-6)   )
     .                 + a3_filt4 * ( FN(J,K,1) + F(J,K,Mx-5)   )
     .                 + a2_filt4 * ( F(J,K,Mx) + F(J,K,Mx-4)   )
     .                 + a1_filt4 * ( F(J,K,Mx-1) + F(J,K,Mx-3) )
     .                 + a0_filt4 *   F(J,K,Mx-2)

          W(N,Mx-1) =    a4_filt4 * ( FN(J,K,3) + F(J,K,Mx-5) )
     .                 + a3_filt4 * ( FN(J,K,2) + F(J,K,Mx-4) )
     .                 + a2_filt4 * ( FN(J,K,1) + F(J,K,Mx-3) )
     .                 + a1_filt4 * ( F(J,K,Mx) + F(J,K,Mx-2) )
     .                 + a0_filt4 *   F(J,K,Mx-1)

          W(N,Mx)   =    a4_filt4 * ( FN(J,K,4) + F(J,K,Mx-4) )
     .                 + a3_filt4 * ( FN(J,K,3) + F(J,K,Mx-3) )
     .                 + a2_filt4 * ( FN(J,K,2) + F(J,K,Mx-2) )
     .                 + a1_filt4 * ( FN(J,K,1) + F(J,K,Mx-1) )
     .                 + a0_filt4 *   F(J,K,Mx)

        End Do
      End Do


*  Solve the matrix system to obtain the derivative dF
      Call pentadiagonal(ldu_filt_x_A, ldu_filt_x_B, ldu_filt_x_C,
     .                   ldu_filt_x_D, ldu_filt_x_E, W,
     .                   Mx, LotX, 1, MPI_X_COMM)

* Converting 2-D array to 3-D for copying
      Do N = 0,LotX-1
       Do I = 1,Mx
         J = N / Mz + 1
         K = MOD(N,Mz) + 1
         W2(J,K,I) = W(N+1,I)
         F0(J,K,I) = W2(J,K,I)
       End Do
      End Do

      Return

      End

*******************************************************************
      Subroutine Compact_Filter_Y(F, F0)

      Include 'header'
      Include 'LES_header'
      Include 'mpif.h'

      Real*8  F(My,Mz,Mx), F0(My,Mz,Mx)
      Real*8  FP(4,Mz,Mx), FN(4,Mz,Mx)
      Real*8  W(LotY, My), W2(My,Mz,Mx)
      Real*8  temp(4,Mz,Mx,2)
      Integer status_arr(MPI_STATUS_SIZE,4), ierr, req(4)


*  Locals
      Integer I, J, K, N

* Putting first 4 and last 4 data planes into temp arrays for sending
      temp(:,:,:,1) = F(1:4,:,:)
      temp(:,:,:,2) = F(My-3:My,:,:)

* Transferring data from neighbouring processors
      Call MPI_IRECV(FP(1,1,1),   Mz*Mx*4, MPI_REAL8,source_right_y,
     .               source_right_y,                                 ! Recv last 4 planes
     .               MPI_XYZ_COMM, req(1), ierr)
 
      Call MPI_IRECV(FN(1,1,1),   Mz*Mx*4, MPI_REAL8,source_left_y,
     .               source_left_y,                                 ! Recv last 4 planes
     .               MPI_XYZ_COMM, req(2), ierr)

      Call MPI_ISEND(temp(1,1,1,2), Mz*Mx*4, MPI_REAL8,dest_right_y,
     .               rank,                                           ! Send last 4 planes
     .               MPI_XYZ_COMM, req(3), ierr)

      Call MPI_ISEND(temp(1,1,1,1), Mz*Mx*4, MPI_REAL8,dest_left_y,
     .               rank,                                           ! Send first 4 planes
     .               MPI_XYZ_COMM, req(4), ierr)


* Compute interior in the meantime
      Do I = 1, Mx
        Do K = 1, Mz
          N =  (I-1) * Mz + K
          Do J = 5, My-4
            W(N,J) =     a4_filt4 * ( F(J+4,K,I) + F(J-4,K,I) )
     .                 + a3_filt4 * ( F(J+3,K,I) + F(J-3,K,I) )
     .                 + a2_filt4 * ( F(J+2,K,I) + F(J-2,K,I) )
     .                 + a1_filt4 * ( F(J+1,K,I) + F(J-1,K,I) )
     .                 + a0_filt4 * F(J,K,I)
          End Do
        End Do
      End Do

*  Wait to recieve planes
      Call MPI_WAITALL(4, req, status_arr, ierr)

      Do I = 1, Mx
        Do K = 1, Mz

          N =  (I-1) * Mz + K

          W(N,1) =      a4_filt4 * ( F(5,K,I) + FP(1,K,I) )
     .                + a3_filt4 * ( F(4,K,I) + FP(2,K,I) )
     .                + a2_filt4 * ( F(3,K,I) + FP(3,K,I) )
     .                + a1_filt4 * ( F(2,K,I) + FP(4,K,I) )
     .                + a0_filt4 *   F(1,K,I)


          W(N,2) =      a4_filt4 * ( F(6,K,I) + FP(2,K,I) )
     .                + a3_filt4 * ( F(5,K,I) + FP(3,K,I) )
     .                + a2_filt4 * ( F(4,K,I) + FP(4,K,I) )
     .                + a1_filt4 * ( F(3,K,I) + F(1,K,I) )
     .                + a0_filt4 *   F(2,K,I)

          W(N,3) =      a4_filt4 * ( F(7,K,I) + FP(3,K,I) )
     .                + a3_filt4 * ( F(6,K,I) + FP(4,K,I) )
     .                + a2_filt4 * ( F(5,K,I) + F(1,K,I) )
     .                + a1_filt4 * ( F(4,K,I) + F(2,K,I) )
     .                + a0_filt4   * F(3,K,I)

          W(N,4) =      a4_filt4 * ( F(8,K,I) + FP(4,K,I) )
     .                + a3_filt4 * ( F(7,K,I) + F(1,K,I) )
     .                + a2_filt4 * ( F(6,K,I) + F(2,K,I) )
     .                + a1_filt4 * ( F(5,K,I) + F(3,K,I) )
     .                + a0_filt4   * F(4,K,I)
        End Do
      End Do

      Do I = 1, Mx
        Do K = 1, Mz

          N =  (I-1) * Mz + K

          W(N,My-3) =    a4_filt4 * ( FN(1,K,I) + F(My-7,K,I) )
     .                 + a3_filt4 * ( F(My,K,I) + F(My-6,K,I) )
     .                 + a2_filt4 * ( F(My-1,K,I) + F(My-5,K,I) )
     .                 + a1_filt4 * ( F(My-2,K,I) + F(My-4,K,I) )
     .                 + a0_filt4 *   F(My-3,K,I)

          W(N,My-2) =    a4_filt4 * ( FN(2,K,I) + F(My-6,K,I) ) 
     .                 + a3_filt4 * ( FN(1,K,I) + F(My-5,K,I) )
     .                 + a2_filt4 * ( F(My,K,I) + F(My-4,K,I) )
     .                 + a1_filt4 * ( F(My-1,K,I) + F(My-3,K,I) )
     .                 + a0_filt4 *   F(My-2,K,I)

          W(N,My-1) =    a4_filt4 * ( FN(3, K,I) + F(My-5,K,I) )
     .                 + a3_filt4 * ( FN(2, K,I) + F(My-4,K,I) )
     .                 + a2_filt4 * ( FN(1, K,I) + F(My-3,K,I) )
     .                 + a1_filt4 * ( F(My,K,I) + F(My-2,K,I) )
     .                 + a0_filt4 * F(My-1,K,I)

          W(N,  My)   =   a4_filt4 * ( FN(4,K,I) + F(My-4,K,I) )
     .                  + a3_filt4 * ( FN(3,K,I) + F(My-3,K,I) )
     .                  + a2_filt4 * ( FN(2,K,I) + F(My-2,K,I) )
     .                  + a1_filt4 * ( FN(1,K,I) + F(My-1,K,I) )
     .                  + a0_filt4 *  F(My,K,I)

        End Do
      End Do

*  Solve the matrix system to obtain the derivative dF
      Call pentadiagonal(ldu_filt_y_A, ldu_filt_y_B, ldu_filt_y_C,
     .                   ldu_filt_y_D, ldu_filt_y_E, W,
     .                   My, LotY, 1, MPI_Y_COMM)

* Converting 2-D array to 3-D for copying
      Do N = 0,LotY-1
       Do J = 1,My
         I = N / Mz + 1
         K = MOD(N,Mz) + 1
         W2(J,K,I) = W(N+1,J)
         F0(J,K,I) = W2(J,K,I)
       End Do
      End Do

      Return

      End

******************************************************************
      Subroutine Compact_Filter_Z(F, F0)

      Include 'header'
      Include 'LES_header'
      Include 'mpif.h'

      Real*8  F(My,Mz,Mx), F0(My,Mz,Mx)
      Real*8  FP(My,4,Mx), FN(My,4,Mx)
      Real*8  W(LotZ, Mz), W2(My,Mz,Mx)
      Real*8  temp(My,4,Mx,2)
      Integer status_arr(MPI_STATUS_SIZE,4), ierr, req(4)

*  Locals
      Integer I, J, K, N

* Putting first 4 and last 4 data planes into temp arrays for sending
      temp(:,:,:,1) = F(:,1:4,:)
      temp(:,:,:,2) = F(:,Mz-3:Mz,:)

* Transferring data from neighbouring processors
      Call MPI_IRECV(FP(1,1,1),    Mx*My*4, MPI_REAL8,source_right_z,
     .               source_right_z,                                 ! Recv last 4 planes
     .               MPI_XYZ_COMM, req(1), ierr)

      Call MPI_IRECV(FN(1,1,1),    Mx*My*4, MPI_REAL8,source_left_z,
     .               source_left_z,                                  ! Recv first 4 planes
     .               MPI_XYZ_COMM, req(2), ierr)

      Call MPI_ISEND(temp(1,1,1,2), Mx*My*4, MPI_REAL8,dest_right_z,
     .               rank,                                           ! Send last 4 planes
     .               MPI_XYZ_COMM, req(3), ierr)

      Call MPI_ISEND(temp(1,1,1,1), Mx*My*4, MPI_REAL8,dest_left_z,
     .               rank,                                           ! Send first 4 planes
     .               MPI_XYZ_COMM, req(4), ierr)

* Compute interior in the meantime
      Do I = 1, Mx
        Do J = 1, My
          N =  (I-1) * My + J
          Do K = 5, Mz-4
            W(N,K) =     a4_filt4 * ( F(J,K+4,I) + F(J,K-4,I) )
     .                 + a3_filt4 * ( F(J,K+3,I) + F(J,K-3,I) )
     .                 + a2_filt4 * ( F(J,K+2,I) + F(J,K-2,I) )
     .                 + a1_filt4 * ( F(J,K+1,I) + F(J,K-1,I) )
     .                 + a0_filt4 * F(J,K,I)
          End Do
        End Do
      End Do

*  Wait to recieve planes
      Call MPI_WAITALL(4, req, status_arr, ierr)

      Do I = 1, Mx
        Do J = 1, My

          N =  (I-1) * My + J

          W(N,1) =      a4_filt4 * ( F(J,5,I) + FP(J,1,I) ) 
     .                + a3_filt4 * ( F(J,4,I) + FP(J,2,I) )
     .                + a2_filt4 * ( F(J,3,I) + FP(J,3,I) )
     .                + a1_filt4 * ( F(J,2,I) + FP(J,4,I) )
     .                + a0_filt4 *   F(J,1,I)


          W(N,2) =      a4_filt4 * ( F(J,6,I) + FP(J,2,I) )
     .                + a3_filt4 * ( F(J,5,I) + FP(J,3,I) )
     .                + a2_filt4 * ( F(J,4,I) + FP(J,4,I) )
     .                + a1_filt4 * ( F(J,3,I) + F(J,1,I) )
     .                + a0_filt4 *   F(J,2,I)

          W(N,3) =      a4_filt4 * ( F(J,7,I) + FP(J,3,I) )
     .                + a3_filt4 * ( F(J,6,I) + FP(J,4,I) )
     .                + a2_filt4 * ( F(J,5,I) + F(J,1,I) )
     .                + a1_filt4 * ( F(J,4,I) + F(J,2,I) )
     .                + a0_filt4   * F(J,3,I)

          W(N,4) =      a4_filt4 * ( F(J,8,I) + FP(J,4,I) )
     .                + a3_filt4 * ( F(J,7,I) + F(J,1,I) )
     .                + a2_filt4 * ( F(J,6,I) + F(J,2,I) )
     .                + a1_filt4 * ( F(J,5,I) + F(J,3,I) )
     .                + a0_filt4   * F(J,4,I)

        End Do
      End Do

      Do I = 1, Mx
        Do J = 1, My

          N =  (I-1) * My + J

          W(N,Mz-3) =    a4_filt4 * ( FN(J,1,I) + F(J,Mz-7,I) )
     .                 + a3_filt4 * ( F(J,Mz,I) + F(J,Mz-6,I) )
     .                 + a2_filt4 * ( F(J,Mz-1,I) + F(J,Mz-5,I) )
     .                 + a1_filt4 * ( F(J,Mz-2,I) + F(J,Mz-4,I) )
     .                 + a0_filt4 *   F(J,Mz-3,I)

          W(N,Mz-2) =    a4_filt4 * ( FN(J,2,I) + F(J,Mz-6,I) )
     .                 + a3_filt4 * ( FN(J,1,I) + F(J,Mz-5,I) )
     .                 + a2_filt4 * ( F(J,Mz,I) + F(J,Mz-4,I) )
     .                 + a1_filt4 * ( F(J,Mz-1,I) + F(J,Mz-3,I) )
     .                 + a0_filt4 *   F(J,Mz-2,I)

          W(N,Mz-1) =    a4_filt4 * ( FN(J,3,I) + F(J,Mz-5,I) )
     .                 + a3_filt4 * ( FN(J,2,I) + F(J,Mz-4,I) )
     .                 + a2_filt4 * ( FN(J,1,I) + F(J,Mz-3,I) )
     .                 + a1_filt4 * ( F(J,Mz,I) + F(J,Mz-2,I) )
     .                 + a0_filt4 *   F(J,Mz-1,I)

          W(N,Mz) =       a4_filt4 * ( FN(J,4,I) + F(J,Mz-4,I) )
     .                  + a3_filt4 * ( FN(J,3,I) + F(J,Mz-3,I) )
     .                  + a2_filt4 * ( FN(J,2,I) + F(J,Mz-2,I) )
     .                  + a1_filt4 * ( FN(J,1,I) + F(J,Mz-1,I) )
     .                  + a0_filt4 *   F(J,Mz,I)

        End Do
      End Do

*  Solve the matrix system to obtain the derivative dF
      Call pentadiagonal(ldu_filt_z_A, ldu_filt_z_B, ldu_filt_z_C,
     .                   ldu_filt_z_D, ldu_filt_z_E, W,
     .                   Mz, LotZ, 1, MPI_Z_COMM)

* Converting 2-D array to 3-D for copying
      Do N = 0,LotZ-1
       Do K = 1,Mz
         I = N / My + 1
         J = MOD(N,My) + 1
         W2(J,K,I) = W(N+1,K)
         F0(J,K,I) = W2(J,K,I)
       End Do
      End Do

      Return

      End

***************************************************************************
* Subroutine : Gaussian Filter                                            *
*                                                                         *
* Applies Gaussian filter as defined in Cook & Cabot, JCP 2004            *
* to the field                                                            *
*                                                                         *
* Input  : Field to be filtered                                           *
* Output : Filtered field                                                 *
***************************************************************************

      Subroutine Gaussian_Filter(F, Fg, N)

      Include 'header'
      Include 'LES_header'

      Real*8 F(My,Mz,Mx,N), Fg(My,Mz,Mx,N)
      Real*8 Fg_tmp(My,Mz,Mx,N)
      
*  Locals
      Integer L, N

      Do L = 1, N
*  Filter in X, Y & Z
         Call Gaussian_Filter_X(F(1,1,1,L), Fg(1,1,1,L))
         Call Gaussian_Filter_Y(Fg(1,1,1,L), Fg_tmp(1,1,1,L))
         Call Gaussian_Filter_Z(Fg_tmp(1,1,1,L), Fg(1,1,1,L))
      End Do

      Return

      End
      

**************************************************************************

      Subroutine Gaussian_Filter_X(F, Fg)

      Include 'header'
      Include 'LES_header'
      Include 'mpif.h'

      Real*8  F(My,Mz,Mx), Fg(My,Mz,Mx)
      Real*8  FP(My,Mz,4), FN(My,Mz,4)
      Real*8  temp(My,Mz,4,2)
      Integer status_arr(MPI_STATUS_SIZE,4), ierr, req(4)

*  Locals
      Integer I, J, K, N

* Putting first 4 and last 4 data planes into temp arrays for sending
      temp(:,:,:,1) = F(:,:,1:4)
      temp(:,:,:,2) = F(:,:,Mx-3:Mx)

* Transferring data from neighbouring processors
      Call MPI_IRECV(FP(1,1,1),   My*Mz*4, MPI_REAL8,source_right_x,
     .               source_right_x,                                 ! Recv last 4 planes
     .               MPI_XYZ_COMM, req(1), ierr)

      Call MPI_IRECV(FN(1,1,1),   My*Mz*4, MPI_REAL8,source_left_x,
     .               source_left_x,                                  ! Recv first 4 planes
     .               MPI_XYZ_COMM, req(2), ierr)

      Call MPI_ISEND(temp(1,1,1,2), My*Mz*4, MPI_REAL8,dest_right_x,
     .               rank,                                           ! Send last 4 planes
     .               MPI_XYZ_COMM, req(3), ierr)

      Call MPI_ISEND(temp(1,1,1,1), My*Mz*4, MPI_REAL8,dest_left_x,
     .               rank,                                           ! Send first 4 planes
     .               MPI_XYZ_COMM, req(4), ierr)

* Compute interior in the meantime
      Do J = 1, My
        Do K = 1, Mz
          Do I = 5, Mx-4
            Fg(J,K,I) =  a4_filt_gauss * ( F(J,K,I+4) + F(J,K,I-4) )
     ,                 + a3_filt_gauss * ( F(J,K,I+3) + F(J,K,I-3) )
     .                 + a2_filt_gauss * ( F(J,K,I+2) + F(J,K,I-2) )
     .                 + a1_filt_gauss * ( F(J,K,I+1) + F(J,K,I-1) )
     .                 + a0_filt_gauss *   F(J,K,I)
          End Do
        End Do
      End Do

*  Wait to recieve planes
      Call MPI_WAITALL(4, req, status_arr, ierr)

      Do J = 1, My
        Do K = 1, Mz

          Fg(J,K,1) =   a4_filt_gauss * ( F(J,K,5) + FP(J,K,1) )
     .                + a3_filt_gauss * ( F(J,K,4) + FP(J,K,2) )
     .                + a2_filt_gauss * ( F(J,K,3) + FP(J,K,3) )
     .                + a1_filt_gauss * ( F(J,K,2) + FP(J,K,4) )
     .                + a0_filt_gauss *   F(J,K,1)

          Fg(J,K,2) =   a4_filt_gauss * ( F(J,K,6) + FP(J,K,2) )
     .                + a3_filt_gauss * ( F(J,K,5) + FP(J,K,3) )
     .                + a2_filt_gauss * ( F(J,K,4) + FP(J,K,4) )
     .                + a1_filt_gauss * ( F(J,K,3) + F(J,K,1)  )
     .                + a0_filt_gauss *   F(J,K,2)

          Fg(J,K,3) =   a4_filt_gauss * ( F(J,K,7) + FP(J,K,3) )
     .                + a3_filt_gauss * ( F(J,K,6) + FP(J,K,4) )
     .                + a2_filt_gauss * ( F(J,K,5) + F(J,K,1)  )
     .                + a1_filt_gauss * ( F(J,K,4) + F(J,K,2)  )
     .                + a0_filt_gauss *   F(J,K,3)

          Fg(J,K,4) =   a4_filt_gauss * ( F(J,K,8) + FP(J,K,4) )
     .                + a3_filt_gauss * ( F(J,K,7) + F(J,K,1)  )
     .                + a2_filt_gauss * ( F(J,K,6) + F(J,K,2)  )
     .                + a1_filt_gauss * ( F(J,K,5) + F(J,K,3)  )
     .                + a0_filt_gauss *   F(J,K,4)
        End Do
      End Do

      Do J = 1, My
        Do K = 1, Mz
          Fg(J,K,Mx-3) = a4_filt_gauss * ( FN(J,K,1)   + F(J,K,Mx-7) )
     .                 + a3_filt_gauss * ( F(J,K,Mx)   + F(J,K,Mx-6) )
     .                 + a2_filt_gauss * ( F(J,K,Mx-1) + F(J,K,Mx-5) )
     .                 + a1_filt_gauss * ( F(J,K,Mx-2) + F(J,K,Mx-4) )
     .                 + a0_filt_gauss *   F(J,K,Mx-3)

          Fg(J,K,Mx-2) = a4_filt_gauss * ( FN(J,K,2)   + F(J,K,Mx-6) )
     .                 + a3_filt_gauss * ( FN(J,K,1)   + F(J,K,Mx-5) )
     .                 + a2_filt_gauss * ( F(J,K,Mx)   + F(J,K,Mx-4) )
     .                 + a1_filt_gauss * ( F(J,K,Mx-1) + F(J,K,Mx-3) )
     .                 + a0_filt_gauss *   F(J,K,Mx-2)

          Fg(J,K,Mx-1) = a4_filt_gauss * ( FN(J,K,3) + F(J,K,Mx-5) )
     .                 + a3_filt_gauss * ( FN(J,K,2) + F(J,K,Mx-4) )
     .                 + a2_filt_gauss * ( FN(J,K,1) + F(J,K,Mx-3) )
     .                 + a1_filt_gauss * ( F(J,K,Mx) + F(J,K,Mx-2) )
     .                 + a0_filt_gauss * F(J,K,Mx-1)

          Fg(J,K,Mx)   = a4_filt_gauss * ( FN(J,K,4) + F(J,K,Mx-4) )
     .                 + a3_filt_gauss * ( FN(J,K,3) + F(J,K,Mx-3) )
     .                 + a2_filt_gauss * ( FN(J,K,2) + F(J,K,Mx-2) )
     .                 + a1_filt_gauss * ( FN(J,K,1) + F(J,K,Mx-1) )
     .                 + a0_filt_gauss *  F(J,K,Mx)

        End Do
      End Do

      Return 

      End

**************************************************************************

      Subroutine Gaussian_Filter_Y(F, Fg)

      Include 'header'
      Include 'LES_header'
      Include 'mpif.h'

      Real*8  F(My,Mz,Mx), Fg(My,Mz,Mx)
      Real*8  FP(4,Mz,Mx), FN(4,Mz,Mx)
      Real*8  temp(4,Mz,Mx,2)
      Integer status_arr(MPI_STATUS_SIZE,4), ierr, req(4)

*  Locals
      Integer I, J, K, N

* Putting first 4 and last 4 data planes into temp arrays for sending
      temp(:,:,:,1) = F(1:4,:,:)
      temp(:,:,:,2) = F(My-3:My,:,:)

* Transferring data from neighbouring processors
      Call MPI_IRECV(FP(1,1,1),   Mz*Mx*4, MPI_REAL8,source_right_y,
     .               source_right_y,                                 ! Recv last 4 planes
     .               MPI_XYZ_COMM, req(1), ierr)

      Call MPI_IRECV(FN(1,1,1),   Mz*Mx*4, MPI_REAL8,source_left_y,
     .               source_left_y,                                  ! Recv first 4 planes
     .               MPI_XYZ_COMM, req(2), ierr)

      Call MPI_ISEND(temp(1,1,1,2), Mz*Mx*4, MPI_REAL8,dest_right_y,
     .               rank,                                           ! Send last 4 planes
     .               MPI_XYZ_COMM, req(3), ierr)

      Call MPI_ISEND(temp(1,1,1,1), Mz*Mx*4, MPI_REAL8,dest_left_y,
     .               rank,                                           ! Send first 4 planes
     .               MPI_XYZ_COMM, req(4), ierr)
 
* Compute interior in the meantime
      Do I = 1, Mx
        Do K = 1, Mz
          Do J = 5, My-4
            Fg(J,K,I) =  a4_filt_gauss * ( F(J+4,K,I) + F(J-4,K,I) )
     .                 + a3_filt_gauss * ( F(J+3,K,I) + F(J-3,K,I) )
     .                 + a2_filt_gauss * ( F(J+2,K,I) + F(J-2,K,I) )
     .                 + a1_filt_gauss * ( F(J+1,K,I) + F(J-1,K,I) )
     .                 + a0_filt_gauss * F(J,K,I)
          End Do
        End Do
      End Do

*  Wait to recieve last 3 planes
      Call MPI_WAITALL(4, req, status_arr, ierr)

      Do I = 1, Mx
        Do K = 1, Mz
          Fg(1,K,I) =   a4_filt_gauss * ( F(5,K,I) + FP(1,K,I) )
     .                + a3_filt_gauss * ( F(4,K,I) + FP(2,K,I) )
     .                + a2_filt_gauss * ( F(3,K,I) + FP(3,K,I) )
     .                + a1_filt_gauss * ( F(2,K,I) + FP(4,K,I) )
     .                + a0_filt_gauss *   F(1,K,I)

          Fg(2,K,I) =   a4_filt_gauss * ( F(6,K,I) + FP(2,K,I) )
     .                + a3_filt_gauss * ( F(5,K,I) + FP(3,K,I) )
     .                + a2_filt_gauss * ( F(4,K,I) + FP(4,K,I) )
     .                + a1_filt_gauss * ( F(3,K,I) + F(1,K,I)  )
     .                + a0_filt_gauss *   F(2,K,I)

          Fg(3,K,I) =   a4_filt_gauss * ( F(7,K,I) + FP(3,K,I) )
     .                + a3_filt_gauss * ( F(6,K,I) + FP(4,K,I) )
     .                + a2_filt_gauss * ( F(5,K,I) + F(1,K,I)  )
     .                + a1_filt_gauss * ( F(4,K,I) + F(2,K,I)  )
     .                + a0_filt_gauss * F(3,K,I)

          Fg(4,K,I) =   a4_filt_gauss * ( F(8,K,I) + FP(4,K,I) )
     .                + a3_filt_gauss * ( F(7,K,I) + F(1,K,I)  )
     .                + a2_filt_gauss * ( F(6,K,I) + F(2,K,I)  )
     .                + a1_filt_gauss * ( F(5,K,I) + F(3,K,I)  )
     .                + a0_filt_gauss * F(4,K,I)
        End Do
      End Do

      Do I = 1, Mx
        Do K = 1, Mz
          Fg(My-3,K,I) = a4_filt_gauss * ( FN(1,K,I)   + F(My-7,K,I) )
     .                 + a3_filt_gauss * ( F(My,K,I)   + F(My-6,K,I) )
     .                 + a2_filt_gauss * ( F(My-1,K,I) + F(My-5,K,I) )
     .                 + a1_filt_gauss * ( F(My-2,K,I) + F(My-4,K,I) )
     .                 + a0_filt_gauss *   F(My-3,K,I)

          Fg(My-2,K,I) = a4_filt_gauss * ( FN(2,K,I)   + F(My-6,K,I) )
     .                 + a3_filt_gauss * ( FN(1,K,I)   + F(My-5,K,I) )
     .                 + a2_filt_gauss * ( F(My,K,I)   + F(My-4,K,I) )
     .                 + a1_filt_gauss * ( F(My-1,K,I) + F(My-3,K,I) )
     .                 + a0_filt_gauss *   F(My-2,K,I)

          Fg(My-1,K,I) = a4_filt_gauss * ( FN(3,K,I)  + F(My-5,K,I) )
     .                 + a3_filt_gauss * ( FN(2,K,I)  + F(My-4,K,I) )
     .                 + a2_filt_gauss * ( FN(1,K,I)  + F(My-3,K,I) )
     .                 + a1_filt_gauss * ( F(My,K,I)  + F(My-2,K,I) )
     .                 + a0_filt_gauss * F(My-1,K,I)

          Fg(My,K,I)   = a4_filt_gauss * ( FN(4,K,I) + F(My-4,K,I) )
     .                 + a3_filt_gauss * ( FN(3,K,I) + F(My-3,K,I) )
     .                 + a2_filt_gauss * ( FN(2,K,I) + F(My-2,K,I) )
     .                 + a1_filt_gauss * ( FN(1,K,I) + F(My-1,K,I) )
     .                 + a0_filt_gauss *  F(My,K,I)
        End Do
      End Do

      Return

      End

**************************************************************************

      Subroutine Gaussian_Filter_Z(F, Fg)

      Include 'header'
      Include 'LES_header'
      Include 'mpif.h'

      Real*8  F(My,Mz,Mx), Fg(My,Mz,Mx)
      Real*8  FP(My,4,Mx), FN(My,4,Mx)
      Real*8  temp(My,4,Mx,2)
      Integer status_arr(MPI_STATUS_SIZE,4), ierr, req(4)

*  Locals
      Integer I, J, K, N

* Putting first 4 and last 4 data planes into temp arrays for sending
      temp(:,:,:,1) = F(:,1:4,:)
      temp(:,:,:,2) = F(:,Mz-3:Mz,:)

* Transferring data from neighbouring processors
      Call MPI_IRECV(FP(1,1,1),    Mx*My*4, MPI_REAL8,source_right_z,
     .               source_right_z,                                 ! Recv last 4 planes
     .               MPI_XYZ_COMM, req(1), ierr)

      Call MPI_IRECV(FN(1,1,1),    Mx*My*4, MPI_REAL8,source_left_z,
     .               source_left_z,                                  ! Recv first 4 planes
     .               MPI_XYZ_COMM, req(2), ierr)

      Call MPI_ISEND(temp(1,1,1,2), Mx*My*4, MPI_REAL8,dest_right_z,
     .               rank,                                           ! Send last 4 planes
     .               MPI_XYZ_COMM, req(3), ierr)
      Call MPI_ISEND(temp(1,1,1,1), Mx*My*4, MPI_REAL8,dest_left_z,
     .               rank,                                           ! Send first 4 planes
     .               MPI_XYZ_COMM, req(4), ierr )

* Compute interior in the meantime
      Do I = 1, Mx
        Do J = 1, My
          Do K = 5, Mz-4
            Fg(J,K,I) =  a4_filt_gauss * ( F(J,K+4,I) + F(J,K-4,I) )
     .                 + a3_filt_gauss * ( F(J,K+3,I) + F(J,K-3,I) )
     .                 + a2_filt_gauss * ( F(J,K+2,I) + F(J,K-2,I) )
     .                 + a1_filt_gauss * ( F(J,K+1,I) + F(J,K-1,I) )
     .                 + a0_filt_gauss *   F(J,K,I)
          End Do
        End Do
      End Do

*  Wait to recieve planes
      Call MPI_WAITALL(4, req, status_arr, ierr)
       
      Do I = 1, Mx
        Do J = 1, My

          Fg(J,1,I) =   a4_filt_gauss * ( F(J,5,I) + FP(J,1,I) )
     .                + a3_filt_gauss * ( F(J,4,I) + FP(J,2,I) )
     .                + a2_filt_gauss * ( F(J,3,I) + FP(J,3,I) )
     .                + a1_filt_gauss * ( F(J,2,I) + FP(J,4,I) )
     .                + a0_filt_gauss *   F(J,1,I)


          Fg(J,2,I) =   a4_filt_gauss * ( F(J,6,I) + FP(J,2,I) ) 
     .                + a3_filt_gauss * ( F(J,5,I) + FP(J,3,I) )
     .                + a2_filt_gauss * ( F(J,4,I) + FP(J,4,I) )
     .                + a1_filt_gauss * ( F(J,3,I) + F(J,1,I)  )
     .                + a0_filt_gauss *   F(J,2,I)

          Fg(J,3,I) =   a4_filt_gauss * ( F(J,7,I) + FP(J,3,I) )
     .                + a3_filt_gauss * ( F(J,6,I) + FP(J,4,I) )
     .                + a2_filt_gauss * ( F(J,5,I) + F(J,1,I)  )
     .                + a1_filt_gauss * ( F(J,4,I) + F(J,2,I)  )
     .                + a0_filt_gauss *   F(J,3,I)

          Fg(J,4,I) =   a4_filt_gauss * ( F(J,8,I) + FP(J,4,I) )
     .                + a3_filt_gauss * ( F(J,7,I) + F(J,1,I)  )
     .                + a2_filt_gauss * ( F(J,6,I) + F(J,2,I)  )
     .                + a1_filt_gauss * ( F(J,5,I) + F(J,3,I)  )
     .                + a0_filt_gauss *   F(J,4,I)

        End Do
      End Do

      Do I = 1, Mx
        Do J = 1, My

          Fg(J,Mz-3,I) = a4_filt_gauss * ( FN(J,1,I)   + F(J,Mz-7,I) )
     .                 + a3_filt_gauss * ( F(J,Mz,I)   + F(J,Mz-6,I) )
     .                 + a2_filt_gauss * ( F(J,Mz-1,I) + F(J,Mz-5,I) )
     .                 + a1_filt_gauss * ( F(J,Mz-2,I) + F(J,Mz-4,I) )
     .                 + a0_filt_gauss *   F(J,Mz-3,I)

          Fg(J,Mz-2,I) = a4_filt_gauss * ( FN(J,2,I)   + F(J,Mz-6,I) )
     .                 + a3_filt_gauss * ( FN(J,1,I)   + F(J,Mz-5,I) )
     .                 + a2_filt_gauss * ( F(J,Mz,I)   + F(J,Mz-4,I) )
     .                 + a1_filt_gauss * ( F(J,Mz-1,I) + F(J,Mz-3,I) )
     .                 + a0_filt_gauss *   F(J,Mz-2,I)

          Fg(J,Mz-1,I) = a4_filt_gauss * ( FN(J,3,I) + F(J,Mz-5,I)  )
     .                 + a3_filt_gauss * ( FN(J,2,I) + F(J,Mz-4,I)  )
     .                 + a2_filt_gauss * ( FN(J,1,I) + F(J,Mz-3,I)  ) 
     .                 + a1_filt_gauss * ( F(J,Mz,I)  + F(J,Mz-2,I) )
     .                 + a0_filt_gauss *   F(J,Mz-1,I)

          Fg(J,Mz,I) =   a4_filt_gauss * ( FN(J,4,I) + F(J,Mz-4,I) )
     .                 + a3_filt_gauss * ( FN(J,3,I) + F(J,Mz-3,I) )
     .                 + a2_filt_gauss * ( FN(J,2,I) + F(J,Mz-2,I) )
     .                 + a1_filt_gauss * ( FN(J,1,I) + F(J,Mz-1,I) )
     .                 + a0_filt_gauss *   F(J,Mz,I)

        End Do
      End Do

      Return

      End
